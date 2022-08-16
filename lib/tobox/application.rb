# frozen_string_literal: true

module Tobox
  class Application
    def initialize(configuration)
      @configuration = configuration
      @running = false
    end

    def start
      return if @running

      worker = @configuration[:worker]

      @pool = case worker
              when :thread then ThreadedPool
              when :fiber then FiberPool
              else worker
              end.new(@configuration)

      @running = true
    end

    def stop
      return unless @running

      @pool.stop

      @running = false
    end
  end
end
