# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "sequel"

DB = begin
  db = if ENV.key?("DATABASE_URL")
         if RUBY_ENGINE == "jruby"
           # All of this magic is because the DATABASE_URL are the kind of random URIS parsed
           # by Rails, but it's incompatible with sequel, which follows the standards of JDBC.
           #
           # for this reason, sequel is initiated by parsing out the correct URI from the env var.
           if ENV["DATABASE_URL"].match(/sqlite3(.*)/)
             # AR: sqlite3::memory:
             # Sequel: jdbc:sqlite::memory:
             # can't test jruby sqlite in parallel mode
             # https://stackoverflow.com/questions/10707434/sqlite-in-a-multithreaded-java-application
             ENV.delete("PARALLEL")
             Sequel.connect("jdbc:sqlite#{Regexp.last_match(1)}")
           elsif ENV["DATABASE_URL"].match(/mysql(.*)/)
             # AR: mysql://user:pass@host/db
             # Sequel: jdbc:mysql://user:pass@host/db
             Sequel.connect("jdbc:mysql#{Regexp.last_match(1)}")
           elsif !ENV["DATABASE_URL"].start_with?("jdbc")
             # AR: postgresql://user:pass@host/db
             # Sequel: jdbc:postgresql://host/db?user=user&password=pass
             uri = URI.parse(ENV["DATABASE_URL"])
             uri.query = "user=#{uri.user}&password=#{uri.password}"
             uri.user = nil
             uri.password = nil
             Sequel.connect("jdbc:#{uri}")
           else
             Sequel.connect(ENV["DATABASE_URL"])
           end
         elsif ENV["DATABASE_URL"].match(/sqlite3(.*)/)
           Sequel.connect("sqlite#{Regexp.last_match(1)}")
         else
           Sequel.connect(ENV["DATABASE_URL"])
         end
       else
         # psql --username=<admin> -c "CREATE ROLE outbox CREATEDB LOGIN PASSWORD 'password'"
         # PGPASSWORD="password" createdb -Uoutbox outbox_test
         Sequel.postgres("outbox_test", user: "outbox", password: "password")
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


class DatabaseTest < Minitest::Test
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