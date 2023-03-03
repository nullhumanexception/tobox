# frozen_string_literal: true

module Tobox
  class Application
    def initialize(configuration)
      @configuration = configuration
      @running = false

      @on_start_handlers = Array(configuration.lifecycle_events[:on_start])
      @on_stop_handlers = Array(configuration.lifecycle_events[:on_stop])

      worker = configuration[:worker]

      @pool = case worker
              when :thread then ThreadedPool
              when :fiber then FiberPool
              else worker
              end.new(configuration)
    end

    def start
      return if @running

      @on_start_handlers.each(&:call)

      @pool.start
      @running = true
    end

    def stop
      return unless @running

      @on_stop_handlers.each(&:call)

      @pool.stop

      @running = false
    end
  end
end
