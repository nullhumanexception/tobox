# frozen_string_literal: true

require "datadog/tracing/contrib/integration"

module Datadog
  module Tracing
    module Contrib
      module Tobox
        class Integration
          include Contrib::Integration

          MINIMUM_VERSION = Gem::Version.new("0.1.0")

          register_as :tobox

          def self.version
            Gem.loaded_specs["tobox"] && Gem.loaded_specs["tobox"].version
          end

          def self.loaded?
            !defined?(::Tobox).nil?
          end

          def self.compatible?
            super && version >= MINIMUM_VERSION
          end

          def new_configuration
            Configuration::Settings.new
          end

          def patcher
            Patcher
          end
        end
      end
    end
  end
end
