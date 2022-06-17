require "forwardable"

module Tobox
  class Configuration
    extend Forwardable

    attr_reader :handlers

    def_delegator :@config, :[]

    DEFAULT_CONFIGURATION = {
      :database => Sequel::DATABASES.first,
      :table => :outbox
    }

    def initialize(name = nil, &block)
      @name = name
      @config = DEFAULT_CONFIGURATION.dup
      @handlers = Hash.new { |hs, event| hs[event] = [] }
      return unless block

      case block.arity
      when 0
        instance_exec(&block)
      when 1
        block.call(self)
      else
        raise Error, "configuration does not support blocks with more than one variable"
      end

      freeze
    end


    def on(event, &callback)
      @handlers[event.to_sym] << callback
      self
    end

    def freeze
      @config.each_value(&:freeze).freeze
      @handlers.each_value(&:freeze).freeze
      super
    end

    private

    def method_missing(meth, *args, &block)
      if DEFAULT_CONFIGURATION.key?(meth) && args.size == 1
        @config[meth] = args.first
      elsif /\Aon\_(.*)\z/.match(meth) && args.size == 0
        on($1.to_sym, &block)
      else
        super
      end
    end
  end
end