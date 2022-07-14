
require "optparse"
require "uri"
require_relative "../tobox"

module Tobox
  class CLI

    def self.run(args = ARGV)
      new(args).run
    end

    def initialize(args)
      @options = parse(args)
    end

    def run
      options = @options

      config = Configuration.new do |c|
        c.instance_eval(File.read(options.fetch(:config_file)), options.fetch(:config_file), 1)
      end

      logger = config[:logger]

      # boot
      options.fetch(:require).each(&method(:require))

      # signals
      pipe_read, pipe_write = IO.pipe
      %w[INT TERM].each do |sig|
        old_handler = Signal.trap(sig) do
          if old_handler.respond_to?(:call)
            begin
              old_handler.call
            rescue Exception => exc
              puts ["Error in #{sig} handler", exc].inspect
            end
          end
          pipe_write.puts(sig)
        end
      rescue ArgumentError
        puts "Signal #{sig} not supported"
      end

      app = Tobox::Application.new(config)

      begin
        app.start

        logger.info "Running tobox-#{Tobox::VERSION} (#{RUBY_DESCRIPTION})"
        logger.info "workers=#{config[:concurrency]}"
        logger.info "Press Ctrl-C to stop"


        while pipe_read.wait_readable
          signal = pipe_read.gets.strip
          handle_signal(signal)
        end

      rescue Interrupt
        logger.info "Shutting down..."
        app.stop
        logger.info "Down!"
        exit(0)
      end
    end

    private

    def parse(args)
      opts = {
        require: []
      }
      parser = OptionParser.new { |o|

        o.on "-C", "--config PATH", "path to tobox .rb config file" do |arg|
          if File.directory?(arg)
            arg = File.join(arg, "tobox.rb")
          end
          raise ArgumentError, "no such file #{arg}" unless File.exists?(arg)
          opts[:config_file] = arg
        end

        o.on "-r", "--require [PATH|DIR]", "Location of application with files to require" do |arg|
          requires = (opts[:require] ||= [])
          if File.directory?(arg)
            requires.concat(Dir.glob(File.join("**", "*.rb")))
          else
            raise ArgumentError, "no such file #{arg}" unless File.exists?(arg)
            requires << arg
          end
        end

        o.on "-d", "--database-uri DATABASE_URI", String, "location of the database with the outbox table" do |arg|
          opts[:database_uri] = URI(arg)
        end

        o.on "-t", "--table TABLENAME", "(optional) name of the outbox database table" do |arg|
          opts[:table] = arg
        end

        o.on "-c", "--concurrency INT", Integer, "processor threads to use" do |arg|
          raise ArgumentError, "must be positive" unless arg > 0
          opts[:concurrency] = arg
        end

        o.on "-g", "--tag TAG", "Process tag for procline" do |arg|
          opts[:tag] = arg
        end

        o.on "-t", "--shutdown-timeout NUM", Integer, "Shutdown timeout (in seconds)" do |arg|
          raise ArgumentError, "must be positive" unless arg > 0
          opts[:shutdown_timeout] = arg
        end

        o.on "--verbose", "Print more verbose output" do |arg|
          opts[:verbose] = arg
        end

        o.on "-v", "--version", "Print version and exit" do |arg|
          puts "Tobox #{Tobox::VERSION}"
          exit(0)
        end
      }

      parser.banner = "tobox [options]"
      parser.on_tail "-h", "--help", "Show help" do
        STDOUT.puts parser
        exit(0)
      end
      parser.parse(args)
      opts
    end

    def handle_signal(sig)
      case sig
      when "INT", "TERM"
        raise Interrupt
      else
        warn "#{sig} is unsupported"
      end
    end
  end
end