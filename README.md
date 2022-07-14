# Tobox: Transactional outbox pattern implementation in ruby

[![Gem Version](https://badge.fury.io/rb/tobox.svg)](http://rubygems.org/gems/tobox)
[![pipeline status](https://gitlab.com/honeyryderchuck/tobox/badges/master/pipeline.svg)](https://gitlab.com/honeyryderchuck/tobox/pipelines?page=1&scope=all&ref=master)
[![coverage report](https://gitlab.com/honeyryderchuck/tobox/badges/master/coverage.svg?job=coverage)](https://honeyryderchuck.gitlab.io/tobox/coverage/#_AllFiles)

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
      column :data_after, :json, null: false
      column :created_at, :time, null: false, default: Sequel::CURRENT_TIMESTAMP
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
on(:user_created) do |_, user_data_hash|
  puts "created user #{user_data_hash["id"]}"
  DataLakeService.user_created(user_data_hash)
  BillingService.bill_user_account(user_data_hash)
end
on(:user_updated) do |user_data_hash_before_update, user_data_hash_after_update|
  # ...
end
```

3. Start the `tobox` process

```
> bundle exec tobox -C path/to/tobox.rb -r path/to/boot.rb
```

There is no API for event production yet (still TODO). It's recommended you write directly into the "outbox" table via database triggers (i.e. *insert into users table -> add user_created event"). Alternatively you can use `sequel` directly (`DB[:outbox].insert(...)`).

## Why?

### Simple and lightweight, framework (and tech stack) agnostic

`tobox` event callbacks yield the data in ruby primitive types, rather than heavy ORM instances. This is by design, as callbacks may not rely on application code being loaded.

This allows `tobox` to process events dispatched from an application done in another programmming language.

However, more monolithic deployments are also possible.

TODO: add exammple

### No second storage system

While `tobox` does not advertise itself as a background job framework, it can be used as such.

Most tiered applications already have an RDBMS. Popular background job solutions, like `"sidekiq"` and `"shoryuken"`, usually require integrating with a separate message broker (Redis, SQS, RabbitMQ...). This increases the overhead in deployment and operations, as these brokers need to be provisioned, monitored, scaled separately, and usually bring its own billing rules.

`tobox` only requires the database you already need to account for anyway, allowing you to delay buying into more complicated setups until you need to and have budget for.

However, it can work well in tandem with such solutions.

TODO: add example.

### Atomic processing via database transactions

When scheduling work, one needs to ensure that data is committed in the database before the scheduling (this is one of the most frequent bugs using non-RDBMS background job frameworks).

But even if you do that, the system can go down **after** the data is committed in the database and **before** the job is enqueued to the broker. Failing to address this behaviour makes the job delivery guarantee "at most once". This may or may not be a problem depending on what your job does (if it bills a customer, it probably is).

By using the database as the message broker, `tobox` can rely on good old transactions to ensure that, when data is committed to the database, the corresponding outbox even is also committed, as long as everything is done within the same database transaction. This makes the delivery guarantee "exactly once".


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://gitlab.com/honeyryderchuck/tobox.
