# frozen_string_literal: true

module Tobox
  class Pool
    def initialize(configuration)
      @configuration = configuration
      @num_workers = configuration[:concurrency]
      @workers = Array.new(@num_workers) do |idx|
        Worker.new("tobox-worker-#{idx}", configuration)
      end
      start
    end

    def stop
      @workers.each(&:finish!)
    end
  end

  autoload :ThreadedPool, File.join(__dir__, "pool", "threaded_pool")
  autoload :FiberPool, File.join(__dir__, "pool", "fiber_pool")
end
