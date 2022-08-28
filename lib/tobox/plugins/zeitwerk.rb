# frozen_string_literal: true

module Tobox
  module Plugins
    module Zeitwerk
      module ConfigurationMethods
        def zeitwerk_loader(loader = nil, &blk)
          if loader
            @zeitwerk_loader = loader
          elsif blk
            @zeitwerk_loader ||= ::Zeitwerk::Loader.new
            yield(@zeitwerk_loader)
          elsif !(loader || blk)
            @zeitwerk_loader
          end
        end

        def freeze
          loader = @zeitwerk_loader

          return super unless loader

          if @config[:environment] == "production"
            loader.setup
            ::Zeitwerk::Loader.eager_load_all
          else
            loader.enable_reloading
            loader.setup
          end

          super
        end
      end

      class << self
        def load_dependencies(*)
          require "zeitwerk"
        end

        def configure(config)
          loader = config.zeitwerk_loader

          return unless loader

          config.on_before_event { |*| loader.reload }
        end
      end
    end

    register_plugin :zeitwerk, Zeitwerk
  end
end
