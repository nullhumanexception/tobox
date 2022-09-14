## [Unreleased]

## [0.1.1] - 2002-09-14

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
