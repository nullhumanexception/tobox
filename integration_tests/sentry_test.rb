# frozen_string_literal: true

require "test_helper"
require "logger"
require "sentry-ruby"
require "tobox"

class SentryTest < DatabaseTest
  include Tobox

  DUMMY_DSN = "http://12345:67890@sentry.localdomain/sentry/42"

  def test_sentry_process_success
    fetcher do |c|
      c.plugin(:sentry)
    end
    init_sentry

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    return_value = fetcher.fetch_events { |_| }
    assert return_value == 1

    transport = Sentry.get_current_client.transport

    assert transport.events.count == 1
    event = transport.events.first
    assert event.tags[:event_type] == "event_created"
  end


  def test_sentry_process_error
    fetcher do |c|
      c.max_attempts 1
      c.plugin(:sentry)
    end
    init_sentry
    Sentry.configuration.tobox.report_after_retries = true

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))

    transient_error = Class.new(StandardError)
    return_value = fetcher.fetch_events { |_|
      raise transient_error, "make it fail"
    }
    assert return_value == 1
    transport = Sentry.get_current_client.transport

    # assert transport.events.count == 1
    event = transport.events.first
    assert event.tags[:event_type] == "event_created"
    assert Sentry::Event.get_message_from_exception(event.to_hash).end_with?("make it fail")

  end

  def test_sentry_process_sentry_metadata
    fetcher do |c|
      c.plugin(:sentry)
    end
    init_sentry

    parent_transaction = Sentry.start_transaction(op: "tobox")

    # with event
    db[:outbox].insert(
      type: "event_created",
      data_after: Sequel.pg_json_wrap({ "foo" => "bar" }),
      metadata: Sequel.pg_json_wrap({ "sentry_trace" => parent_transaction.to_sentry_trace })
    )
    return_value = fetcher.fetch_events { |_| }
    assert return_value == 1

    transport = Sentry.get_current_client.transport

    assert transport.events.count == 1
    event = transport.events.first
    assert event.tags[:event_type] == "event_created"
    assert event.contexts.dig(:trace, :trace_id) == parent_transaction.trace_id
  end

  def test_sentry_worker_error
    pool do |c|
      c.plugin(:sentry)
    end
    init_sentry

    worker = Class.new(Worker) do
      def work
        raise "what the hell"
      end
    end.new("test", pool.instance_variable_get(:@configuration)) # random object not responding to #work

    error = nil
    begin
      pool.do_work(worker)
    rescue => err
      error = err
    end

    transport = Sentry.get_current_client.transport

    # assert transport.events.count == 1
    event = transport.events.first
    assert Sentry::Event.get_message_from_exception(event.to_hash).include?("what the hell")
  end

  private

  def init_sentry
    Sentry.init do |config|
      config.dsn = DUMMY_DSN
      config.logger = ::Logger.new(nil)
      config.traces_sample_rate = 1.0
      config.background_worker_threads = 0
      config.transport.transport_class = Sentry::DummyTransport
      yield(config) if block_given?
    end
  end

  def fetcher(&blk)
    @fetcher ||= Fetcher.new("test", Configuration.new(&blk))
  end

  def pool(&blk)
    @pool ||= Class.new(Pool) do
      def start; end
    end.new(Configuration.new(&blk))
  end
end if RUBY_VERSION >= "2.4.0"
