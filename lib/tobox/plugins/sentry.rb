# frozen_string_literal: true

module Tobox
  module Plugins
    module Sentry
      class Configuration
        # Set this option to true if you want Sentry to only capture the last job
        # retry if it fails.
        attr_accessor :report_after_retries

        def initialize
          @report_after_retries = false
        end
      end

      class EventHandler
        TOBOX_NAME = "tobox"

        def initialize(config)
          @config = config
          @db_table = @config[:table]
          @db_scheme = URI(@config[:database_uri]).scheme if @config[:database_uri]
          @max_attempts = @config[:max_attempts]
        end

        def on_start(event)
          return unless ::Sentry.initialized?

          ::Sentry.clone_hub_to_current_thread

          scope = ::Sentry.get_current_scope

          scope.set_contexts(
            id: event[:id],
            type: event[:type],
            attempts: event[:attempts],
            created_at: event[:created_at],
            run_at: event[:run_at],
            last_error: event[:last_error]&.byteslice(0..1000),
            version: Tobox::VERSION,
            db_adapter: @db_scheme
          )
          scope.set_tags(
            outbox: @db_table,
            event_id: event[:id],
            event_type: event[:type]
          )

          scope.set_transaction_name("#{TOBOX_NAME}/#{event[:type]}") unless scope.transaction_name

          transaction = start_transaction(scope.transaction_name, event[:metadata].to_h["sentry_trace"])

          return unless transaction

          scope.set_span(transaction)

          # good for thread pool, good for fiber pool
          store_transaction(event, transaction)
        end

        def on_finish(event)
          return unless ::Sentry.initialized?

          transaction = retrieve_transaction(event)

          return unless transaction

          finish_transaction(transaction, 200)

          scope = ::Sentry.get_current_scope
          scope.clear
        end

        def on_error(event, error)
          return unless ::Sentry.initialized?

          capture_exception(event, error)

          transaction = retrieve_transaction(event)

          return unless transaction

          finish_transaction(transaction, 500)
        end

        private

        def start_transaction(transaction_name, sentry_trace)
          options = { name: transaction_name, op: "tobox" }
          transaction = ::Sentry::Transaction.from_sentry_trace(sentry_trace, **options) if sentry_trace
          ::Sentry.start_transaction(transaction: transaction, **options)
        end

        def finish_transaction(transaction, status)
          transaction.set_http_status(status)
          transaction.finish
        end

        def store_transaction(event, transaction)
          store = (Thread.current[:tobox_sentry_transactions] ||= {})

          store[event[:id]] = transaction
        end

        def retrieve_transaction(event)
          return unless (store = Thread.current[:tobox_sentry_transactions])

          store.delete(event[:id])
        end

        def capture_exception(event, error)
          return unless ::Sentry.configuration.tobox.report_after_retries && event[:attempts] >= @max_attempts

          ::Sentry.capture_exception(
            error,
            hint: { background: false }
          )
        end
      end

      class << self
        def load_dependencies(*)
          require "uri"
          require "sentry-ruby"
        end

        def configure(config)
          event_handler = EventHandler.new(config)
          config.on_before_event(&event_handler.method(:on_start))
          config.on_after_event(&event_handler.method(:on_finish))
          config.on_error_event(&event_handler.method(:on_error))

          config.on_error_worker do |error|
            ::Sentry.capture_exception(error, hint: { background: false })
          end

          ::Sentry::Configuration.attr_reader(:tobox)
          ::Sentry::Configuration.add_post_initialization_callback do
            @tobox = Plugins::Sentry::Configuration.new
          end
        end
      end
    end

    register_plugin :sentry, Sentry
  end
end
