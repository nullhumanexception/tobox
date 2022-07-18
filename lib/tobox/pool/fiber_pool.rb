# frozen_string_literal: true

require "timeout"
require "fiber_scheduler"

module Tobox
  class FiberPool < Pool
    class KillError < Interrupt; end

    def initialize(*)
      Sequel.extension(:fiber_concurrency)
      super
      @error_handlers = Array(@configuration.lifecycle_events[:error])
    end

    def start
      @fiber_thread = Thread.start do
        Thread.current.name = "tobox-fibers-thread"

        FiberScheduler do
          @workers.each_with_index do |wk, _idx|
            Fiber.schedule do
              wk.work
            rescue KillError
              # noop
            rescue Exception => e # rubocop:disable Lint/RescueException
              @error_handlers.each { |hd| hd.call(:tobox_error, e) }
              raise e
            end
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
