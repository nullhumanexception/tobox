# frozen_string_literal: true

require "json"

module Tobox
  class Fetcher
    def initialize(label, configuration)
      @label = label
      @configuration = configuration

      @logger = @configuration.default_logger

      database_uri = @configuration[:database_uri]
      @db = database_uri ? Sequel.connect(database_uri.to_s) : Sequel::DATABASES.first
      raise Error, "no database found" unless @db

      @db.extension :date_arithmetic

      @db.loggers << @logger unless @configuration[:environment] == "production"

      @table = configuration[:table]
      @group_column = configuration[:group_column]
      @exponential_retry_factor = configuration[:exponential_retry_factor]

      max_attempts = configuration[:max_attempts]

      @ds = @db[@table]

      run_at_conds = [
        { Sequel[@table][:run_at] => nil },
        (Sequel.expr(Sequel[@table][:run_at]) < Sequel::CURRENT_TIMESTAMP)
      ].reduce { |agg, cond| Sequel.expr(agg) | Sequel.expr(cond) }

      @pick_next_sql = @ds.where(Sequel[@table][:attempts] < max_attempts) # filter out exhausted attempts
                          .where(run_at_conds)
                          .order(Sequel.desc(:run_at, nulls: :first), :id)

      @before_event_handlers = Array(@configuration.lifecycle_events[:before_event])
      @after_event_handlers = Array(@configuration.lifecycle_events[:after_event])
      @error_event_handlers = Array(@configuration.lifecycle_events[:error_event])
    end

    def fetch_events(&blk)
      num_events = 0
      @db.transaction(savepoint: false) do
        if @group_column
          group = @pick_next_sql.for_update
                                .skip_locked
                                .limit(1)
                                .select(@group_column)

          # get total from a group, to compare to the number of future locked rows.
          total_from_group = @ds.where(@group_column => group).count

          event_ids = @ds.where(@group_column => group)
                         .order(Sequel.desc(:run_at, nulls: :first), :id)
                         .for_update.skip_locked.select_map(:id)

          if event_ids.size != total_from_group
            # this happens if concurrent workers locked different rows from the same group,
            # or when new rows from a given group have been inserted after the lock has been
            # acquired
            event_ids = []
          end

          # lock all, process 1
          event_ids = event_ids[0, 1]
        else
          event_ids = @pick_next_sql.for_update
                                    .skip_locked
                                    .limit(1).select_map(:id) # lock starts here
        end

        events = nil
        error = nil
        unless event_ids.empty?
          @db.transaction(savepoint: true) do
            events = @ds.where(id: event_ids).returning.delete

            if blk
              num_events = events.size

              events.each do |ev|
                ev[:metadata] = try_json_parse(ev[:metadata])
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
        end

        return blk ? 0 : [] if events.nil?

        return events unless blk

        if events
          events.each do |event|
            if error
              event.merge!(mark_as_error(event, error))
              handle_error_event(event, error)
            else
              handle_after_event(event)
            end
          end
        end
      end

      num_events
    end

    private

    def log_message(msg)
      "(worker: #{@label}) -> #{msg}"
    end

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
        before: try_json_parse(event[:data_before]),
        after: try_json_parse(event[:data_after]),
        at: event[:created_at]
      }
    end

    def try_json_parse(data)
      return unless data

      data = JSON.parse(data.to_s) unless data.respond_to?(:to_hash)

      data
    end

    def handle_before_event(event)
      @logger.debug do
        log_message("outbox event (type: \"#{event[:type]}\", attempts: #{event[:attempts]}) starting...")
      end
      @before_event_handlers.each do |hd|
        hd.call(event)
      end
    end

    def handle_after_event(event)
      @logger.debug { log_message("outbox event (type: \"#{event[:type]}\", attempts: #{event[:attempts]}) completed") }
      @after_event_handlers.each do |hd|
        hd.call(event)
      end
    end

    def handle_error_event(event, error)
      @logger.error do
        log_message("outbox event (type: \"#{event[:type]}\", attempts: #{event[:attempts]}) failed with error\n" \
                    "#{error.class}: #{error.message}\n" \
                    "#{error.backtrace.join("\n")}")
      end
      @error_event_handlers.each do |hd|
        hd.call(event, error)
      end
    end
  end
end
