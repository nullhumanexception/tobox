# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in tobox.gemspec
gemspec

# gem "sequel", path: "../sequel"
gem "rake", "~> 13.0"

gem "minitest"
gem "minitest-hooks"
gem "rubocop", require: false
gem "rubocop-performance", require: false
gem "rubocop-rubycw", require: false
gem "simplecov", require: false

# Integrations

gem "ddtrace", require: false
gem "sentry-ruby", require: false

if RUBY_VERSION >= "3.1.0"
  gem "debug"
  gem "fiber_scheduler"
end

platform :mri, :truffleruby do
  if RUBY_VERSION >= "3.0.0"
    gem "rbs"
    gem "steep"
  end

  if RUBY_VERSION < "2.5"
    gem "byebug", "~> 11.0.1"
    gem "pry-byebug", "~> 3.7.0"
  else
    gem "pry-byebug"
  end
  # gem "sqlite3"
  # gem "mysql2"
  gem "pg"
end

platform :jruby do
  # gem "activerecord-jdbc-adapter"
  gem "jdbc-postgres"
  # gem "jdbc-mysql"
  # gem "jdbc-sqlite3"
end
