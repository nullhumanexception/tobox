module Tobox
  class Worker
    def initialize(configuration)
      @wait_for_events_delay = configuration[:wait_for_events_delay]
      @message_to_arguments = configuration[:message_to_arguments]
      @handlers = configuration.handlers
      @fetcher = Fetcher.new(configuration)
      @finished = false
    end

    def finish!
      @finished = true
    end

    def work
      do_work until @finished
    end

    def do_work
      sum_fetched_events = @fetcher.fetch_events do |event|
        event_type = event[:type].to_sym
        event = @message_to_arguments[event] if @message_to_arguments

        @handlers[event_type].each do |handler|

          handler.call(event)

        end if @handlers.key?(event_type)
      end

      return if @finished

      sleep(@wait_for_events_delay) if sum_fetched_events.zero?
    end
  end
end