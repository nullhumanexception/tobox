# frozen_string_literal: true

require "forwardable"

module Tobox
  class Configuration
    extend Forwardable

    attr_reader :handlers, :lifecycle_events

    def_delegator :@config, :[]

    DEFAULT_CONFIGURATION = {
      database_uri: nil,
      table: :outbox,
      wait_for_events_delay: 5,
      shutdown_timeout: 10,
      message_to_arguments: nil,
      concurrency: 4 # TODO: CPU count
    }.freeze

    def initialize(name = nil, &block)
      @name = name
      @config = DEFAULT_CONFIGURATION.dup

      @lifecycle_events = {}
      @handlers = {}
      return unless block

      case block.arity
      when 0
        instance_exec(&block)
      when 1
        yield(self)
      else
        raise Error, "configuration does not support blocks with more than one variable"
      end

      freeze
    end

    def on(event, &callback)
      (@handlers[event.to_sym] ||= []) << callback
      self
    end

    def handle_lifecycle_event(event, &callback)
      (@lifecycle_events[event.to_sym] ||= []) << callback
      self
    end

    def freeze
      @name.freeze
      @config.each_value(&:freeze).freeze
      @handlers.each_value(&:freeze).freeze
      @lifecycle_events.each_value(&:freeze).freeze
      super
    end

    private

    def method_missing(meth, *args, &block)
      if DEFAULT_CONFIGURATION.key?(meth) && args.size == 1
        @config[meth] = args.first
      elsif /\Aon_(.*)\z/.match(meth) && args.size.zero?
        on(Regexp.last_match(1).to_sym, &block)
      else
        super
      end
    end

    def respond_to_missing?(meth, *args)
      super(meth, *args) ||
        DEFAULT_CONFIGURATION.key?(meth) ||
        /\Aon_(.*)\z/.match(meth)
    end
  end
end
