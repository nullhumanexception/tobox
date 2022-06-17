require "forwardable"

module Tobox
  class Configuration
    extend Forwardable

    def_delegator :@config, :[]

    DEFAULT_CONFIGURATION = {
      :database => Sequel::DATABASES.first,
      :table => :outbox
    }

    def initialize
      @config = DEFAULT_CONFIGURATION.dup
      yield if block_given?
    end



    private

    def method_missing(meth, *args, &block)
      if DEFAULT_CONFIGURATION.key?(meth) && args.size == 1
        @config[meth] = args.first
      else
        super
      end
    end
  end
end