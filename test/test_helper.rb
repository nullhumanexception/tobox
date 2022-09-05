# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

if ENV.key?("CI")
  require "simplecov"
  commands = [RUBY_ENGINE, RUBY_VERSION, ENV.fetch("DATABASE_URL", "")[%r{(\w+):(//|:)}, 1]].compact
  SimpleCov.command_name commands.join("-")
  coverage_key = ENV.fetch("COVERAGE_KEY", "#{RUBY_ENGINE}-#{RUBY_VERSION}")
  SimpleCov.coverage_dir "coverage/#{coverage_key}"
end

require "json"
require "logger"
require "sequel"

DB = begin
  db = if ENV.key?("DATABASE_URL")
         if RUBY_ENGINE == "jruby"
           # All of this magic is because the DATABASE_URL are the kind of random URIS parsed
           # by Rails, but it's incompatible with sequel, which follows the standards of JDBC.
           #
           # for this reason, sequel is initiated by parsing out the correct URI from the env var.
           if ENV.fetch("DATABASE_URL", nil) =~ /sqlite3(.*)/
             # AR: sqlite3::memory:
             # Sequel: jdbc:sqlite::memory:
             # can't test jruby sqlite in parallel mode
             # https://stackoverflow.com/questions/10707434/sqlite-in-a-multithreaded-java-application
             ENV.delete("PARALLEL")
             Sequel.connect("jdbc:sqlite#{Regexp.last_match(1)}")
           elsif ENV.fetch("DATABASE_URL", nil) =~ /mysql(.*)/
             # AR: mysql://user:pass@host/db
             # Sequel: jdbc:mysql://user:pass@host/db
             Sequel.connect("jdbc:mysql#{Regexp.last_match(1)}")
           elsif !ENV["DATABASE_URL"].start_with?("jdbc")
             # AR: postgresql://user:pass@host/db
             # Sequel: jdbc:postgresql://host/db?user=user&password=pass
             uri = URI.parse(ENV.fetch("DATABASE_URL", nil))
             uri.query = "user=#{uri.user}&password=#{uri.password}"
             uri.user = nil
             uri.password = nil
             Sequel.connect("jdbc:#{uri}")
           else
             Sequel.connect(ENV.fetch("DATABASE_URL", nil))
           end
         elsif ENV.fetch("DATABASE_URL", nil) =~ /sqlite3(.*)/
           Sequel.connect("sqlite#{Regexp.last_match(1)}")
         else
           Sequel.connect(ENV.fetch("DATABASE_URL", nil))
         end
       else
         # psql --username=<admin> -c "CREATE ROLE outbox CREATEDB LOGIN PASSWORD 'password'"
         # PGPASSWORD="password" createdb -Uoutbox outbox_test
         db_uri = "postgresql://outbox:password@localhost/outbox_test"
         if RUBY_ENGINE == "jruby"
           uri = URI.parse(db_uri)
           uri.query = "user=#{uri.user}&password=#{uri.password}"
           uri.user = nil
           uri.password = nil
           db_uri = "jdbc:#{uri}"
         end
         Sequel.connect(db_uri)
       end
  # seeing weird pool timeout errors from sequel, only in CI
  ENV.delete("PARALLEL") if RUBY_ENGINE == "truffleruby"

  db.loggers << Logger.new($stderr) if ENV.key?("TOBOX_DEBUG")
  Sequel.extension :migration
  # Due to rails test having to mutate the Rodauth::Rails::App singleton, and being the rails
  # application a singleton itself, it's impossible to guarantee thread safety when running the
  # tests in parallel. Hence, there are no parallel tests when rails is around.
  #
  # also, migrations are run with the roda ar connection object.
  #
  #
  if defined?(Rails)
    ENV.delete("PARALLEL")
  else
    Sequel::Migrator.run(db, "test/migrate")
  end

  Sequel.extension :pg_json
  db
end

require "tobox"
require "minitest/autorun"
require "minitest/hooks"

module WithTestLogger
  private

  def make_configuration(&blk)
    Tobox::Configuration.new do |c|
      c.logger(Logger.new(File::NULL))
      yield c if blk
    end
  end
end

class DatabaseTest < Minitest::Test
  include Minitest::Hooks
  include WithTestLogger

  private

  def around
    db.transaction(rollback: :always, savepoint: true, auto_savepoint: true) do
      super
    end
  end

  def db
    DB
  end
end
