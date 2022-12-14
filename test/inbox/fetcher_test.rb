# frozen_string_literal: true

require "test_helper"

class InboxFetcherTest < DatabaseTest
  include Tobox

  def test_fetch_event_error_unique_ids
    errors = []
    fetcher do |c|
      c.inbox_table :inbox
      c.inbox_column :unique_id
      c.on_error_event { |event, error| errors << [event, error] }
    end
    outbox_ds.insert(type: "event_created", unique_id: "foo",  data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    outbox_ds.insert(type: "event_created", unique_id: "bar",  data_after: Sequel.pg_json_wrap({ "foo2" => "bar2" }))
    outbox_ds.insert(type: "event_created", unique_id: "foo",  data_after: Sequel.pg_json_wrap({ "foo3" => "bar3" }))

    events = []
    3.times { fetcher.fetch_events { |ev| events << ev } }

    assert events.size == 2

    assert events[0][:after] == { "foo" => "bar" }
    assert events[1][:after] == { "foo2" => "bar2" }

    assert inbox_ds.count == 2
  end

  private

  def outbox_ds
    db[:outbox]
  end

  def inbox_ds
    db[:inbox]
  end

  def fetcher
    @fetcher ||= Fetcher.new("test", make_configuration do |cfg|
      cfg.table :outbox
      yield(cfg)
    end)
  end
end
