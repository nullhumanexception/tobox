module Tobox
  class Pool

    def initialize(configuration)
      @configuration = configuration
      @num_workers = configuration[:concurrency]
      @workers = @num_workers.times.map { Worker.new(configuration) }
      start
    end

    def stop
      @workers.each(&:finish!)
    end
  end
end

require_relative "pool/threaded_pool"