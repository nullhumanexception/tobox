# frozen_string_literal: true

require "timeout"
require "fiber_scheduler"

module Tobox
  class FiberPool < Pool
    class KillError < Interrupt; end

    def initialize(_configuration)
      Sequel.extension(:fiber_concurrency)
      super
    end

    def start
      @fiber_thread = Thread.start do
        Thread.current.name = "tobox-fibers-thread"

        FiberScheduler do
          @workers.each_with_index do |wk, _idx|
            Fiber.schedule { do_work(wk) }
          end
        end
      end
    end

    def stop
      shutdown_timeout = @configuration[:shutdown_timeout]

      super

      begin
        Timeout.timeout(shutdown_timeout) { @fiber_thread.value }
      rescue Timeout::Error
        # hard exit
        @fiber_thread.raise(KillError)
        @fiber_thread.value
      end
    end
  end
end
