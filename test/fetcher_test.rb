# frozen_string_literal: true

require "test_helper"

class FetcherTest < DatabaseTest
  include Tobox

  def test_fetch_event
    # no event, nothing comes out
    event = fetcher.fetch_event
    assert event.nil?

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar"}))
    event = fetcher.fetch_event
    assert !event.nil?
    assert event[:type] == "event_created"
    assert event[:data_after] == JSON.dump({ "foo" => "bar" })
    next_event = fetcher.fetch_event
    assert next_event.nil?

    # error recovery
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar"}))

    transient_error = Class.new(StandardError)
    begin
      fetcher.fetch_event do |event|
        assert event[:type] == "event_created"
        assert event[:data_after] == JSON.dump({ "foo" => "bar" })
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
