module Tobox
    class RactorPool < Pool
      class KillError < Interrupt; end

      def initialize(configuration)
        @ractors = []
        @configuration = configuration
        @num_workers = configuration[:concurrency]
        start
      end

      def start
        @num_workers.times do |idx|
          rc = Ractor.new(@configuration, name: "tobox-worker-#{idx}") do |configuration|
            error_handlers = Array(configuration.lifecycle_events[:error])
            wk = Worker.new(configuration)

            pool.listen_for_stop(wk)
            begin
              wk.work
            rescue KillError
              # noop
            rescue Exception => error
              error_handlers.each { |hd| hd.call(:tobox_error, error) }
              raise error
            end
            @ractors.delete(Ractor.current)
          end
          @ractors << rc
        end
      end

      def stop
        @ractors.each { |rc| rc.send(:exit) }

        shutdown_timeout = @configuration[:shutdown_timeout]

        deadline = Process.clock_gettime(::Process::CLOCK_MONOTONIC)

        # soft exit
        while Process.clock_gettime(::Process::CLOCK_MONOTONIC) - deadline < shutdown_timeout
          return if @ractors.empty?
          sleep 0.5
        end

        # hard exit
        @ractors.each { |rc| rc.send(:kill) }
      end

      private

      def listen_for_stop(wk)
        Thread.start(wk) do |worker|
          loop do
            case code = Ractor.receive
            when :exit
              worker.finish!
            when :kill
            when :log

            end
          end
        end
      end
    end
  end