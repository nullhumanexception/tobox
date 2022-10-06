# frozen_string_literal: true

require "datadog/tracing/contrib"
require "datadog/tracing/contrib/configuration/settings"
require "datadog/tracing/span_operation"

module Datadog
  module Tracing
    module Contrib
      module Tobox
        module Configuration
          class Settings < Contrib::Configuration::Settings
            option :enabled do |o|
              o.default { env_to_bool("DD_TOBOX_SIDEKIQ_ENABLED", true) }
              o.lazy
            end

            option :analytics_enabled do |o|
              o.default { env_to_bool("DD_TOBOX_ANALYTICS_ENABLED", false) }
              o.lazy
            end

            option :analytics_sample_rate do |o|
              o.default { env_to_float("DD_TRACE_TOBOX_ANALYTICS_SAMPLE_RATE", 1.0) }
              o.lazy
            end

            option :service_name
            option :error_handler, default: Tracing::SpanOperation::Events::DEFAULT_ON_ERROR
            option :distributed_tracing, default: false
          end
        end
      end
    end
  end
end
