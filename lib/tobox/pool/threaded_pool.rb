module Tobox
    class ThreadedPool < Pool
      class KillError < Interrupt; end

      def initialize(*)
        @threads = []
        super
      end

      def start
        @workers.each_with_index do |wk, idx|
          th = Thread.start do
            Thread.current.name = "tobox-worker-#{idx}"

            begin
              wk.work
            rescue KillError
              # noop
            rescue Exception => error
              @configuration.lifecycle_events[:error].each { |hd| hd.call(:tobox_error, error) }
              raise error
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