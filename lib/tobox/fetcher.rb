# frozen_string_literal: true

require "json"

module Tobox
  class Fetcher
    def initialize(configuration)
      @configuration = configuration

      @logger = @configuration.default_logger

      database_uri = @configuration[:database_uri]
      @db = database_uri ? Sequel.connect(database_uri.to_s) : Sequel::DATABASES.first
      @db.extension :date_arithmetic

      raise Error, "no database found" unless @db

      @table = configuration[:table]
      @exponential_retry_factor = configuration[:exponential_retry_factor]

      max_attempts = configuration[:max_attempts]

      @ds = @db[@table]

      @pick_next_sql = @ds.where(Sequel[@table][:attempts] < max_attempts) # filter out exhausted attempts
                          .where(Sequel[@table][:run_at] => nil)
                          .or(Sequel.expr(Sequel[@table][:run_at]) < Sequel::CURRENT_TIMESTAMP)
                          .order(Sequel.desc(:run_at, nulls: :first), :id)
                          .for_update
                          .skip_locked
                          .limit(1)

      @before_event_handlers = Array(@configuration.lifecycle_events[:before_event])
      @after_event_handlers = Array(@configuration.lifecycle_events[:after_event])
      @error_event_handlers = Array(@configuration.lifecycle_events[:error_event])
    end

    def fetch_events(&blk)
      num_events = 0
      @db.transaction do
        event_ids = @pick_next_sql.select_map(:id) # lock starts here

        events = nil
        error = nil
        @db.transaction(savepoint: true) do
          events = @ds.where(id: event_ids).returning.delete

          if blk
            num_events = events.size

            events.each do |ev|
              ev[:metadata] = JSON.parse(ev[:metadata].to_s) if ev[:metadata]
              handle_before_event(ev)
              yield(to_message(ev))
            rescue StandardError => e
              error = e
              raise Sequel::Rollback
            end
          else
            events.map!(&method(:to_message))
          end
        end

        return events unless events && blk

        events.each do |event|
          if error
            event.merge!(mark_as_error(event, error))
            handle_error_event(event, error)
          else
            handle_after_event(event)
          end
        end
      end

      num_events
    end

    private

    def mark_as_error(event, error)
      @ds.where(id: event[:id]).returning.update(
        attempts: Sequel[@table][:attempts] + 1,
        run_at: Sequel.date_add(Sequel::CURRENT_TIMESTAMP,
                                seconds: event[:attempts] + (1**@exponential_retry_factor)),
        # run_at: Sequel.date_add(Sequel::CURRENT_TIMESTAMP,
        #                         seconds: Sequel.function(:POWER, Sequel[@table][:attempts] + 1,  4)),
        last_error: "#{error.message}\n#{error.backtrace.join("\n")}"
      ).first
    end

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
      @logger.debug { "outbox event (type: \"#{event[:type]}\", attempts: #{event[:attempts]}) starting..." }
      @before_event_handlers.each do |hd|
        hd.call(event)
      end
    end

    def handle_after_event(event)
      @logger.debug { "outbox event (type: \"#{event[:type]}\", attempts: #{event[:attempts]}) completed" }
      @after_event_handlers.each do |hd|
        hd.call(event)
      end
    end

    def handle_error_event(event, error)
      @logger.error do
        "outbox event (type: \"#{event[:type]}\", attempts: #{event[:attempts]}) failed with error\n" \
          "#{error.class}: #{error.message}\n" \
          "#{error.backtrace.join("\n")}"
      end
      @error_event_handlers.each do |hd|
        hd.call(event, error)
      end
    end
  end
end
