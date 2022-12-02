# frozen_string_literal: true

require "monitor"

module Tobox
  class ThreadedPool < Pool
    def initialize(_configuration)
      @parent_thread = Thread.main
      @threads = []
      @threads.extend(MonitorMixin)
      super
    end

    def start
      @workers.each_with_index do |wk, idx|
        th = Thread.start do
          Thread.current.name = "tobox-worker-#{idx}"

          do_work(wk)

          @threads.synchronize do
            @threads.delete(Thread.current)

            # all workers went down abruply, we need to kill the process.
            @parent_thread.raise(Interrupt) if wk.finished? && @threads.empty? && @running
          end
        end
        @threads.synchronize do
          @threads << th
        end
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
