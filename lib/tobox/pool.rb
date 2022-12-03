# frozen_string_literal: true

module Tobox
  class Pool
    class KillError < Interrupt; end

    def initialize(configuration)
      @configuration = configuration
      @logger = @configuration.default_logger
      @num_workers = configuration[:concurrency]
      @workers = Array.new(@num_workers) do |idx|
        Worker.new("tobox-worker-#{idx}", configuration)
      end
      @worker_error_handlers = Array(@configuration.lifecycle_events[:error_worker])
      @running = true
      start
    end

    def stop
      return unless @running

      @workers.each(&:finish!)
      @running = false
    end

    def do_work(wrk)
      wrk.work
    rescue KillError
    # noop
    rescue Exception => e # rubocop:disable Lint/RescueException
      wrk.finish!
      @logger.error do
        "(worker: #{wrk.label}) -> " \
          "crashed with error\n" \
          "#{e.class}: #{e.message}\n" \
          "#{e.backtrace.join("\n")}"
      end
      @worker_error_handlers.each { |hd| hd.call(e) }
    end
  end

  autoload :ThreadedPool, File.join(__dir__, "pool", "threaded_pool")
  autoload :FiberPool, File.join(__dir__, "pool", "fiber_pool")
end
