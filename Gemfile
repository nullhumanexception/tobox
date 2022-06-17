# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in tobox.gemspec
gemspec

gem "rake", "~> 13.0"

gem "minitest"
gem "minitest-hooks"

gem "rubocop", "~> 1.21"

platform :mri, :truffleruby do
  if RUBY_VERSION < "2.5"
    gem "byebug", "~> 11.0.1"
    gem "pry-byebug", "~> 3.7.0"
  else
    gem "pry-byebug"
  end
  gem "sqlite3"

  gem "mysql2"
  gem "pg"
end