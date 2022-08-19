# frozen_string_literal: true

require "json"

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

      @before_event_handlers = Array(@configuration.lifecycle_events[:before_event])
      @after_event_handlers = Array(@configuration.lifecycle_events[:after_event])
      @error_event_handlers = Array(@configuration.lifecycle_events[:error_event])
    end

    def fetch_events
      num_events = 0
      @db.transaction do
        events = @ds.where(id: @pick_next_sql).returning.delete

        return events.map(&method(:to_message)) unless block_given?

        num_events = events.size

        events.each do |ev|
          handle_before_event(ev)
          yield(to_message(ev))
        rescue StandardError => e
          handle_error_event(ev, e)
          raise Sequel::Rollback
        ensure
          handle_after_event(ev)
        end
      end

      num_events
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

    def handle_before_event(event)
      @before_event_handlers.each do |hd|
        hd.call(event)
      end
    end

    def handle_after_event(event)
      @after_event_handlers.each do |hd|
        hd.call(event)
      end
    end

    def handle_error_event(event, error)
      @error_event_handlers.each do |hd|
        hd.call(event, error)
      end
    end
  end
end
