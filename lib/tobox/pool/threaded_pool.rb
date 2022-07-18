# frozen_string_literal: true

module Tobox
  class ThreadedPool < Pool
    class KillError < Interrupt; end

    def initialize(*)
      @threads = []
      super
      @error_handlers = Array(@configuration.lifecycle_events[:error])
    end

    def start
      @workers.each_with_index do |wk, idx|
        th = Thread.start do
          Thread.current.name = "tobox-worker-#{idx}"

          begin
            wk.work
          rescue KillError
            # noop
          rescue Exception => e # rubocop:disable Lint/RescueException
            @error_handlers.each { |hd| hd.call(:tobox_error, e) }
            raise e
          end

          @threads.delete(Thread.current)
        end
        @threads << th
      end
    end

    def stop
      shutdown_timeout = @configuration[:shutdown_timeout]

      deadline = Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      super
      Thread.pass # let workers finish

      # soft exit
      while Process.clock_gettime(::Process::CLOCK_MONOTONIC) - deadline < shutdown_timeout
        return if @threads.empty?

        sleep 0.5
      end

      # hard exit
      @threads.each { |th| th.raise(KillError) }
      while (th = @threads.pop)
        th.value # waits
      end
    end
  end
end
