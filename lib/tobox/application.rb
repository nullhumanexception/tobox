# frozen_string_literal: true

module Tobox
  class Application
    def initialize(configuration)
      @configuration = configuration
      @running = false

      worker = @configuration[:worker]

      @pool = case worker
              when :thread then ThreadedPool
              when :fiber then FiberPool
              else worker
              end.new(@configuration)
    end

    def start
      return if @running

      @pool.start
      @running = true
    end

    def stop
      return unless @running

      @pool.stop

      @running = false
    end
  end
end
