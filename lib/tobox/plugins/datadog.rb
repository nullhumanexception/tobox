# frozen_string_literal: true

require_relative "datadog/configuration"
require_relative "datadog/integration"
require_relative "datadog/patcher"

module Tobox
  module Plugins
    module Datadog
      class EventHandler
        def initialize(config)
          @config = config
          @db_table = @config[:table]
        end

        def on_start(event)
          datadog_config = ::Datadog.configuration.tracing[:tobox]
          service = datadog_config[:service_name]
          error_handler = datadog_config[:error_handler]

          analytics_enabled = datadog_config[:analytics_enabled]
          analytics_sample_rate = datadog_config[:analytics_sample_rate]
          distributed_tracing = datadog_config[:distributed_tracing]

          resource = event[:type]

          if (metadata = event[:metadata])
            previous_span = metadata["datadog-parent-id"]

            if distributed_tracing && previous_span
              trace_digest = ::Datadog::Tracing::TraceDigest.new(
                span_id: previous_span,
                trace_id: event[:metadata]["datadog-trace-id"],
                trace_sampling_priority: event[:metadata]["datadog-sampling-priority"],
                trace_origin: event[:metadata]["datadog-origin"]
              )
              ::Datadog::Tracing.continue_trace!(trace_digest)
            end
          end

          span = ::Datadog::Tracing.trace(
            "tobox.event",
            service: service,
            span_type: ::Datadog::Tracing::Metadata::Ext::AppTypes::TYPE_WORKER,
            on_error: error_handler
          )
          span.resource = resource

          span.set_tag(::Datadog::Tracing::Metadata::Ext::TAG_COMPONENT, "tobox")
          span.set_tag(::Datadog::Tracing::Metadata::Ext::TAG_OPERATION, "event")

          if ::Datadog::Tracing::Contrib::Analytics.enabled?(analytics_enabled)
            ::Datadog::Tracing::Contrib::Analytics.set_sample_rate(span, analytics_sample_rate)
          end

          # Measure service stats
          ::Datadog::Tracing::Contrib::Analytics.set_measured(span)

          span.set_tag("tobox.event.id", event[:id])
          span.set_tag("tobox.event.type", event[:type])
          span.set_tag("tobox.event.retry", event[:attempts])
          span.set_tag("tobox.event.table", @db_table)
          span.set_tag("tobox.event.delay", (Time.now.utc - event[:created_at]).to_f)

          event[:__tobox_event_span] = span
        end

        def on_finish(event)
          span = event[:__tobox_event_span]

          return unless span

          span.finish
        end

        def on_error(event, error)
          span = event[:__tobox_event_span]

          return unless span

          span.set_error(error)
          span.finish
        end
      end

      class << self
        def load_dependencies(*)
          require "uri"
        end

        def configure(config)
          event_handler = EventHandler.new(config)
          config.on_before_event(&event_handler.method(:on_start))
          config.on_after_event(&event_handler.method(:on_finish))
          config.on_error_event(&event_handler.method(:on_error))
        end
      end
    end

    register_plugin :datadog, Datadog
  end
end
