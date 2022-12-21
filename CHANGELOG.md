## [Unreleased]

## [0.3.0] - 2022-12-12

### Features

#### Inbox

Implementation of the "inbox pattern", which ensures that events are processed to completion only once.

```ruby
# create an inbox table and reference it
create_table(:inbox) do
  column :id, :varchar, null: true, primary_key: true
  # ...
create_table(:outbox) do
  column :inbox_id, :varchar
  foreign_key :inbox_id, :inbox
  # ...

# tobox.rb
inbox_table :inbox
inbox_column :inbox_id

# event production
DB[:outbox].insert(event_type: "order_created", inbox_id: "order_created_#{order.id}", ....
DB[:outbox].insert(event_type: "billing_event_started", inbox_id: "billing_event_started_#{order.id}", ....
```

## [0.2.0] - 2022-12-05

### Features

#### Ordered event processing

When the outbox table contains a `:group_id` table (and the producer fills up events with it), then a group of events with the same `:group_id` will be processed one by one, by order of insertion.

```ruby
# migration
create_table(:outbox) do
  column :message_group_id, :integer

# tobox.rb
message_group_column :group_id

# event production
DB[:outbox].insert(event_type: "order_created", message_group_id: order.id, ....
DB[:outbox].insert(event_type: "billing_event_started", message_group_id: order.id, ....

# order_created handled first, billing_event_started only after
```

#### on_error_worker callback

The config option `on_error_worker { |error| }` gets called when an error happens in a worker **before** events are processed (p.ex. when the database connection becomes unhealthy). You can use it to report such errors to an error reporting system (the `sentry` plugin relies on it).

```ruby
# tobox.rb
on_error_worker { |error| Sentry.capture_exception(error, hint: { background: false }) }
```

### Bugfixes

Thread workers: when errors happen which bring down the workers (such as database becoming unresponsive), workers will be restarted.

## [0.1.6] - 2022-10-06

### Bugfixes

Allow passing datadog options, initialize tracing from plugin.

## [0.1.5] - 2022-10-06

### Bugfixes

Fixing datadog plugin name.

## [0.1.4] - 2022-10-06

### Bugfixes

Actual fix for missing datadog constants.

## [0.1.3] - 2022-10-06

### Bugfixes

Datadog constants unproperly namespaced.

## [0.1.2] - 2022-09-14

### Bugfixes

Actual fix for foregoing json parsing.

## [0.1.1] - 2022-09-14

### Chore

Improved default logger, by logging the thread name, as well as providing the worker id in the lifecycle event logs.

### Bugfixes

Do not try to json parse already parsed json columns (this happens if the DB object already has `:pg_json` extension loaded).

## [0.1.0] - 2022-09-05

- Initial release.

* `tobox` entrypoint to start the consumer.
* `sentry` integration.
* `datadog` integration.
* `zeitwerk` integration.
