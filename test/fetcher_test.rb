# frozen_string_literal: true

require "test_helper"

class FetcherTest < DatabaseTest
  include Tobox

  def test_fetch_events
    # no event, nothing comes out
    events = fetcher.fetch_events
    assert events.empty?

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    events = fetcher.fetch_events
    assert !events.empty?
    event = events.first
    assert event[:type] == "event_created"
    assert event[:after] == { "foo" => "bar" }
    next_events = fetcher.fetch_events
    assert next_events.empty?

    # with block
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    return_value = fetcher.fetch_events { |_| }
    assert return_value == 1
    return_value = fetcher.fetch_events { |_| }
    assert return_value.zero?

    # error recovery
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))

    transient_error = Class.new(StandardError)
    begin
      fetcher.fetch_events do |fetched_event|
        assert fetched_event[:type] == "event_created"
        assert fetched_event[:after] == { "foo" => "bar" }
        assert db[:outbox].count.zero?

        raise transient_error, "make it fail"
      end
    rescue transient_error
      # ignore
    end
    assert !db[:outbox].count.zero?
  end

  private

  def fetcher
    @fetcher ||= Fetcher.new(Configuration.new)
  end
end
