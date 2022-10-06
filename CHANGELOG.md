## [Unreleased]

## [0.1.5] - 2002-10-06

### Bugfixes

Fixing datadog plugin name.

## [0.1.4] - 2002-10-06

### Bugfixes

Actual fix for missing datadog constants.

## [0.1.3] - 2002-10-06

### Bugfixes

Datadog constants unproperly namespaced.

## [0.1.2] - 2002-09-14

### Bugfixes

Actual fix for foregoing json parsing.

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
