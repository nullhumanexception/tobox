# frozen_string_literal: true

module Tobox
  class Pool
    class KillError < Interrupt; end

    def initialize(configuration)
      @configuration = configuration
      @num_workers = configuration[:concurrency]
      @workers = Array.new(@num_workers) do |idx|
        Worker.new("tobox-worker-#{idx}", configuration)
      end
      @error_handlers = Array(@configuration.lifecycle_events[:error])
      start
    end

    def stop
      @workers.each(&:finish!)
    end

    def do_work(wrk)
      wrk.work
    rescue KillError
    # noop
    rescue Exception => e # rubocop:disable Lint/RescueException
      @error_handlers.each { |hd| hd.call(:tobox_error, e) }
      raise e
    end
  end

  autoload :ThreadedPool, File.join(__dir__, "pool", "threaded_pool")
  autoload :FiberPool, File.join(__dir__, "pool", "fiber_pool")
end
