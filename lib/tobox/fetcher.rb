# frozen_string_literal: true

module Tobox
  class Fetcher
    def initialize(configuration)
      @configuration = configuration

      database_uri = @configuration[:database_uri]
      @db = database_uri ? Sequel.connect(database_uri.to_s) : Sequel::DATABASES.first

      raise Error, "no database found" unless @db

      table = configuration[:table]

      @ds = @db[table]

      @pick_next_sql = @ds.select(:id).order(:id).for_update.skip_locked.limit(1)

      @error_handlers = Array(@configuration.lifecycle_events[:error])
    end

    def fetch_events
      @db.transaction do
        events = @ds.where(id: @pick_next_sql).returning.delete

        return events.map(&method(:to_message)) unless block_given?

        events.each do |ev|
          yield(to_message(ev))
        rescue StandardError => e
          handle_error(ev, e)
          raise Sequel::Rollback
        end
        return events.size
      end
    end

    private

    def to_message(event)
      {
        id: event[:id],
        type: event[:type],
        before: (JSON.parse(event[:data_before].to_s) if event[:data_before]),
        after: (JSON.parse(event[:data_after].to_s) if event[:data_after]),
        at: event[:created_at]
      }
    end

    def handle_error(event, error)
      @error_handlers.each do |hd|
        hd.call(event, error)
      end
    end
  end
end
