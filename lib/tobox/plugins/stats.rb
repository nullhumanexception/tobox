# frozen_string_literal: true

module Tobox
  module Plugins
    module Stats
      module ConfigurationMethods
        attr_reader :stats_interval_seconds

        def on_stats(stats_interval_seconds, &callback)
          @stats_interval_seconds = stats_interval_seconds

          (@lifecycle_events[:stats] ||= []) << callback
          self
        end
      end

      class StatsEmitter
        def initialize(config)
          @config = config
          @running = false
        end

        def start
          return if @running

          config = @config

          interval = config.stats_interval_seconds
          @stats_handlers = Array(config.lifecycle_events[:stats])
          @error_handlers = Array(config.lifecycle_events[:error_worker])

          @max_attempts = config[:max_attempts]

          db = config.database
          @outbox_table = config[:table]
          @outbox_ds = db[@outbox_table]

          inbox_table = config[:inbox_table]
          @inbox_ds = db[inbox_table] if inbox_table

          @th = Thread.start do
            Thread.current.name = "outbox-stats"

            loop do
              puts "sleep for #{interval}"
              sleep interval

              begin
                emit_event_stats
              rescue RuntimeError => e
                @error_handlers.each { |hd| hd.call(e) }
              end

              break unless @running
            end
          end

          @running = true
        end

        def stop
          return unless @running

          @th.terminate

          @running = false
        end

        private

        def emit_event_stats
          stats = @outbox_ds.group_and_count(
            Sequel.case([
                          [{ last_error: nil }, "pending_count"],
                          [Sequel.expr([:attempts]) < @max_attempts, "failing_count"]
                        ],
                        "failed_count").as(:status)
          )
          stats = stats.as_hash(:status, :count).transform_keys(&:to_sym)

          # fill it in
          stats[:pending_count] ||= 0
          stats[:failing_count] ||= 0
          stats[:failed_count] ||= 0

          stats[:inbox_count] = @inbox_ds.count if @inbox_ds

          @stats_handlers.each do |hd|
            hd.call(stats)
          end
        end
      end

      class << self
        def configure(config)
          emitter = StatsEmitter.new(config)

          config.on_start(&emitter.method(:start))
          config.on_stop(&emitter.method(:stop))
        end
      end
    end

    register_plugin :stats, Stats
  end
end
