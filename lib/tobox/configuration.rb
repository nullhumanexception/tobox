# frozen_string_literal: true

require "logger"
require "forwardable"

module Tobox
  class Configuration
    extend Forwardable

    attr_reader :handlers, :lifecycle_events, :arguments_handler, :default_logger

    def_delegator :@config, :[]

    DEFAULT_CONFIGURATION = {
      environment: ENV.fetch("APP_ENV", "development"),
      logger: nil,
      log_level: nil,
      database_uri: nil,
      table: :outbox,
      group_column: nil,
      max_attempts: 10,
      exponential_retry_factor: 4,
      wait_for_events_delay: 5,
      shutdown_timeout: 10,
      concurrency: 4, # TODO: CPU count
      worker: :thread
    }.freeze

    LOG_FORMAT_PATTERN = "%s, [%s #%d (th: %s)] %5s -- %s: %s\n"
    DEFAULT_LOG_FORMATTER = Class.new(Logger::Formatter) do
      def call(severity, time, progname, msg)
        format(LOG_FORMAT_PATTERN, severity[0, 1], format_datetime(time), Process.pid,
               Thread.current.name || Thread.current.object_id, severity, progname, msg2str(msg))
      end
    end.new

    def initialize(name = nil, &block)
      @name = name
      @config = DEFAULT_CONFIGURATION.dup

      @lifecycle_events = {}
      @handlers = {}
      @message_to_arguments = nil
      @plugins = []

      if block
        case block.arity
        when 0
          instance_exec(&block)
        when 1
          yield(self)
        else
          raise Error, "configuration does not support blocks with more than one variable"
        end
      end

      env = @config[:environment]
      @default_logger = @config[:logger] || Logger.new(STDERR, formatter: DEFAULT_LOG_FORMATTER) # rubocop:disable Style/GlobalStdStream
      @default_logger.level = @config[:log_level] || (env == "production" ? Logger::INFO : Logger::DEBUG)

      freeze
    end

    def on(event, &callback)
      (@handlers[event.to_sym] ||= []) << callback
      self
    end

    def on_before_event(&callback)
      (@lifecycle_events[:before_event] ||= []) << callback
      self
    end

    def on_after_event(&callback)
      (@lifecycle_events[:after_event] ||= []) << callback
      self
    end

    def on_error_event(&callback)
      (@lifecycle_events[:error_event] ||= []) << callback
      self
    end

    def on_error_worker(&callback)
      (@lifecycle_events[:error_worker] ||= []) << callback
      self
    end

    def message_to_arguments(&callback)
      @arguments_handler = callback
      self
    end

    def plugin(plugin, **options, &block)
      raise Error, "Cannot add a plugin to a frozen config" if frozen?

      plugin = Plugins.load_plugin(plugin) if plugin.is_a?(Symbol)

      return if @plugins.include?(plugin)

      @plugins << plugin
      plugin.load_dependencies(self, **options, &block) if plugin.respond_to?(:load_dependencies)

      extend(plugin::ConfigurationMethods) if defined?(plugin::ConfigurationMethods)

      plugin.configure(self, **options, &block) if plugin.respond_to?(:configure)
    end

    def freeze
      @name.freeze
      @config.each_value(&:freeze).freeze
      @handlers.each_value(&:freeze).freeze
      @lifecycle_events.each_value(&:freeze).freeze
      @plugins.freeze
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
