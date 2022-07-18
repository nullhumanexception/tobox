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
            @workers.each_with_index do |wk, idx|
              Fiber.schedule do
                begin
                  wk.work
                rescue KillError
                  # noop
                rescue Exception => error
                  @error_handlers.each { |hd| hd.call(:tobox_error, error) }
                  raise error
                end
              end
            end
          end
        end
      end

      def stop
        shutdown_timeout = @configuration[:shutdown_timeout]

        deadline = Process.clock_gettime(::Process::CLOCK_MONOTONIC)

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