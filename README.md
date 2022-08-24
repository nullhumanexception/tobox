# Tobox: Transactional outbox pattern implementation in ruby

[![Gem Version](https://badge.fury.io/rb/tobox.svg)](http://rubygems.org/gems/tobox)
[![pipeline status](https://gitlab.com/honeyryderchuck/tobox/badges/master/pipeline.svg)](https://gitlab.com/honeyryderchuck/tobox/pipelines?page=1&scope=all&ref=master)
[![coverage report](https://gitlab.com/honeyryderchuck/tobox/badges/master/coverage.svg?job=coverage)](https://honeyryderchuck.gitlab.io/tobox/#_AllFiles)

Simple, data-first events processing framework based on the [transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html).

## Requirements

`tobox` requires integration with RDBMS which supports `SKIP LOCKED` functionality. As of today, that's:

* PostgreSQL 9.5+
* MySQL 8+
* Oracle
* Microsoft SQL Server

## Installation

Add this line to your application's Gemfile:

```ruby
gem "tobox"

# You'll also need to aadd the right database client gem for the target RDBMS
# ex, for postgresql:
#
# gem "pg"
# see more: http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install tobox

## Usage

1. create the `outbox` table in your application's database:

```ruby
# example migration using sequel
Sequel.migration do
  up do
    create_table(:outbox) do
      primary_key :id
      column :type, :varchar, null: false
      column :data_before, :json, null: true
      column :data_after, :json, null: true
      column :created_at, "timestamp without time zone", null: false, default: Sequel::CURRENT_TIMESTAMP
      column :attempts, :integer, null: false, default: 0
      column :run_at, "timestamp without time zone", null: true
      column :last_error, :text, null: true
      column :metadata, :json, null: true

      index Sequel.desc(:run_at)
    end
  end

  down do
    drop_table(:outbox)
  end
end
```
2. create a `tobox.rb` config file in your project directory tree:

```ruby
# tobox
database Sequel.connect("postgres://user:pass@dbhost/database")
# table :outbox
# concurrency 8
on("user_created") do |event|
  puts "created user #{event[:after]["id"]}"
  DataLakeService.user_created(user_data_hash)
  BillingService.bill_user_account(user_data_hash)
end
on("user_updated") do |event|
  # ...
end
```

3. Start the `tobox` process

```
> bundle exec tobox -C path/to/tobox.rb -r path/to/file_requiring_application_code.rb
```

There is no API for event production yet (still TODO). It's recommended you write directly into the "outbox" table via database triggers (i.e. *insert into users table -> add user_created event"). Alternatively you can use `sequel` directly (`DB[:outbox].insert(...)`).

4. Emit outbox events

Currently, `tobox` only deals with outbox events consumption. When it comes to producing, you can do it yourself. There essentially two alternatives:

4.1 Emit from application code

If you're using `sequel` as your ORM, you can use the dataset API:

```ruby
# Assuming DB points to your `Sequel::Database`, and defaults are used:
order = Order.new(
  item_id: item.id,
  price: 20_20,
  currency: "EUR"
)
DB.transaction do
  order.save
  DB[:outbox].insert(event_type: "order_created", data_after: order.to_hash)
end
```

4.2 Emit from database trigger

This is how it could be done in PostgreSQL using trigger functions:

```sql
CREATE OR REPLACE FUNCTION order_created_outbox_event()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
	INSERT INTO outbox(event_type, data_after)
		 VALUES('order_created', row_to_json(NEW.*));
	RETURN NEW;
END;
$$

CREATE TRIGGER order_created_outbox_event
  AFTER INSERT
  ON orders
  FOR EACH ROW
  EXECUTE PROCEDURE order_created_outbox_event();
```

## Configuration

As mentioned above, configuration can be set in a particular file. The following options are configurable:

### `database_uri`

Accepts a URI pointing to a database, [where scheme identifies the database adapter to be used](https://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html):

```ruby
database_uri `"postgres://user:password@localhost/blog"`.
```

### `table`

the name of the database table where outbox events are stored (`:outbox` by default).

```ruby
table :outbox
```

### `max_attempts`

Maximum number of times a failed attempt to process an event will be retried (`10` by default).

```ruby
concurrency 4
```

**Note**: the new attempt will be retried in `n ** 4`, where `n` is the number of past attempts for that event.

### `concurrency`

Number of workers processing events.

```ruby
concurrency 4
```

**Note**: the default concurrency is adapted and different for each worker pool type, so make sure you understand how this tweak may affect you.

### `worker`

Type of the worker used to process events. Can be `:thread` (default), `:fiber`, or a class implementing the `Tobox::Pool` protocol (TBD: define what this protocol is).

### `wait_for_events_delay`

Time (in seconds) to wait before checking again for events in the outbox.

### `shutdown_timeout`

Time (in seconds) to wait for events to finishing processing, before hard-killing the process.

### `on(event_type) { |before, after| }`

callback executed when processing an event of the given type. By default, it'll yield the state of data before and after the event (unless `message_to_arguments` is set).

```ruby
on("order_created") { |event| puts "order created: #{event[:after]}" }
on("order_updated") { |event| puts "order created: was #{event[:before]}, now is #{event[:after]}" }
# ...
```

### `on_before_event { |event| }`

callback executed right before proocessing an event.


```ruby
on_before_event { |event| start_trace(event[:id]) }
```

### `on_after_event { |event| }`

callback executed right after proocessing an event.


```ruby
on_before_event { |event| finish_trace(event[:id]) }
```

### `on_error_event { |event, error| }`

callback executed when an exception was raised while processing an event.


```ruby
on_error_event { |event, exception| Sentry.capture_exception(exception) }
```

### `message_to_arguments { |event| }`

if exposing raw data to the `on` handlers is not what you'd want, you can always override the behaviour by providing an alternative "before/after fetcher" implementation.

```ruby
# if you'd like to yield the ORM object only
message_to_arguments do |event|
case event_type
when "order_created", "order_updated"
  Order.get(after[:id])
when "payment_created", "payment_processed", "payment_reconciled"
  Payment.get(after[:id])
else
  super(event)
end
on("order_created") { |order| puts "order created: #{order}" }
# ...
on("payment_created") { |payment| puts "payment created: #{payment}" }
# ...
```

## Event

The event is composed of the following properties:

* `:id`: unique event identifier
* `:type`: label identifying the event (i.e. `"order_created"`)
* `:before`: hash of the associated event data before event is emitted (can be `nil`)
* `:after`: hash of the associated event data after event is emitted (can be `nil`)
* `:created_at`: timestamp of when the event is emitted

(*NOTE*: The event is also composed of other properties which are only relevant for `tobox`.)

## Rails support

Rails is supported out of the box by adding the [sequel-activerecord_connection](https://github.com/janko/sequel-activerecord_connection) gem into your Gemfile, and requiring the rails application in the `tobox` cli call:

```bash
> bundle exec tobox -C path/to/tobox.rb -r path/to/rails_app/config/environment.rb
```

## Why?

### Simple and lightweight, framework (and programming language) agnostic

`tobox` event callbacks yield the data in ruby primitive types, rather than heavy ORM instances. This is by design, as callbacks may not rely on application code being loaded.

This allows `tobox` to process events dispatched from an application done in another programmming language, as an example.


### No second storage system

While `tobox` does not advertise itself as a background job framework, it can be used as such.

Most tiered applications already have an RDBMS. Popular background job solutions, like `"sidekiq"` and `"shoryuken"`, usually require integrating with a separate message broker (Redis, SQS, RabbitMQ...). This increases the overhead in deployment and operations, as these brokers need to be provisioned, monitored, scaled separately, and billed differently.

`tobox` only requires the database you usually need to account for anyway, allowing you to delay buying into more complicated setups until you have to and have budget for.

However, it can work well in tandem with such solutions:

```ruby
# process event by scheduling an active job
on("order_created") { |event| SendOrderMailJob.perform_later(event[:after]["id"]) }
```

### Atomic processing via database transactions

When scheduling work, one needs to ensure that data is committed to the database before scheduling. This is a very frequent bug when using non-RDBMS background job frameworks, such as [Sidekiq, which has a FAQ entry for this](https://github.com/mperham/sidekiq/wiki/FAQ#why-am-i-seeing-a-lot-of-cant-find-modelname-with-id12345-errors-with-sidekiq) .

But even if you do that, the system can go down **after** the data is committed in the database and **before** the job is enqueued to the broker. Failing to address this behaviour makes the [job delivery guarantee "at most once"](https://brandur.org/job-drain). This may or may not be a problem depending on what your job does (if it bills a customer, it probably is).

By using the database as the message broker, `tobox` can rely on good old transactions to ensure that data committed to the database has a corresponding event. This makes the delivery guarantee "exactly once".

(The actual processing may change this to "at least once", as issues may happen before the event is successfully deleted from the outbox. Still, "at least once" is acceptable and solvable using idempotency mechanisms).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://gitlab.com/honeyryderchuck/tobox.
