# frozen_string_literal: true

module Tobox
  class Worker
    def initialize(label, configuration)
      @wait_for_events_delay = configuration[:wait_for_events_delay]
      @handlers = configuration.handlers || {}
      @fetcher = Fetcher.new(label, configuration)
      @finished = false

      return unless (message_to_arguments = configuration.arguments_handler)

      define_singleton_method(:message_to_arguments, &message_to_arguments)
    end

    def finish!
      @finished = true
    end

    def work
      do_work until @finished
    end

    private

    def do_work
      return if @finished

      sum_fetched_events = @fetcher.fetch_events do |event|
        event_type = event[:type].to_sym
        args = message_to_arguments(event)

        if @handlers.key?(event_type)
          @handlers[event_type].each do |handler|
            handler.call(args)
          end
        end
      end

      return if @finished

      sleep(@wait_for_events_delay) if sum_fetched_events.zero?
    end

    def message_to_arguments(event)
      event
    end
  end
end
