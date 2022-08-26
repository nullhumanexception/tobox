# frozen_string_literal: true

require "test_helper"
require "logger"
require "ddtrace"
require "tobox"

class DatadogTest < DatabaseTest
  include Tobox

  def test_datadog_process_success
    fetcher do |c|
      c.plugin(:datadog)
    end
    set_datadog

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    return_value = fetcher.fetch_events { |_| }
    assert return_value == 1

    span, _push = spans
    assert span.service == tracer.default_service
    assert span.resource == "event_created"
    assert span.get_tag('tobox.event.type') == 'event_created'
    assert span.status == 0

    assert span.get_metric('_dd.measured') == 1.0
    assert span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT) == "tobox"
    assert span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION) == 'event'
  end


  def test_datadog_process_error
    fetcher do |c|
      c.max_attempts 1
      c.plugin(:datadog)
    end
    set_datadog

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))

    return_value = fetcher.fetch_events { |_|
      raise ZeroDivisionError, 'job error'
    }
    assert return_value == 1

    span, _push = spans
    assert span.service == tracer.default_service
    assert span.resource == "event_created"
    assert span.get_tag('tobox.event.type') == 'event_created'

    assert span.status == Datadog::Tracing::Metadata::Ext::Errors::STATUS
    assert span.get_metric('_dd.measured') == 1.0
    assert span.get_tag(Datadog::Tracing::Metadata::Ext::Errors::TAG_MSG) == 'job error'
    assert span.get_tag(Datadog::Tracing::Metadata::Ext::Errors::TAG_TYPE) == 'ZeroDivisionError'
  end

  def test_datadog_process_datadog_metadata
    fetcher do |c|
      c.plugin(:datadog)
    end
    set_datadog(distributed_tracing: true)

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }),
    metadata: Sequel.pg_json_wrap({ "datadog-trace-id" => "TRACE_ID", "datadog-parent-id" => "SPAN_ID", "datadog-origin" => "service1", "datadog-sampling-priority" => 1 }))
    return_value = fetcher.fetch_events { |_| }
    assert return_value == 1

    span, _push = spans
    assert span.service == tracer.default_service
    assert span.resource == "event_created"
    assert span.get_tag('tobox.event.type') == 'event_created'
    assert span.status == 0

    assert span.get_metric('_dd.measured') == 1.0
    assert span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT) == "tobox"
    assert span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION) == 'event'

    assert span.trace_id == "TRACE_ID"
    assert span.parent_id == "SPAN_ID"
  end

  private

  # def setup
  #   super
  #   Datadog.registry[:tobox].reset_configuration!
  # end

  def teardown
    super
    Datadog.registry[:tobox].reset_configuration!
  end

  def set_datadog(options = {}, &blk)
    Datadog.configure do |c|
      c.tracing.instrument(:tobox, options, &blk)
    end

    tracer # initialize tracer patches
  end

  def spans
    @spans ||= fetch_spans
  end

  # Retrieves and sorts all spans in the current tracer instance.
  # This method does not cache its results.
  def fetch_spans
    spans = (tracer.instance_variable_get(:@traces) || []).map(&:spans)
    spans.flatten.sort! do |a, b|
      if a.name == b.name
        if a.resource == b.resource
          if a.start_time == b.start_time
            a.end_time <=> b.end_time
          else
            a.start_time <=> b.start_time
          end
        else
          a.resource <=> b.resource
        end
      else
        a.name <=> b.name
      end
    end
  end

  def tracer
    @tracer ||= begin
      tr = Datadog::Tracing.send(:tracer)
      def tr.write(trace)
        @traces ||= []
        @traces << trace
      end
      tr
    end
  end



  def fetcher(&blk)
    @fetcher ||= Fetcher.new(Configuration.new(&blk))
  end
end if RUBY_VERSION >= "2.4.0"
