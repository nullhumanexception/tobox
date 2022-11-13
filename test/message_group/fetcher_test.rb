# frozen_string_literal: true

require "test_helper"

class MessageGroupFetcherTest < DatabaseTest
  include Tobox

  def test_fetch_events_group_column
    fetcher do |c|
      c.group_column :group_id
    end
    # with event
    outbox_ds.insert(type: "event_created", group_id: 2, data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    outbox_ds.insert(type: "event_created", group_id: 2, data_after: Sequel.pg_json_wrap({ "foo2" => "bar2" }))
    outbox_ds.insert(type: "event_created", group_id: 1, data_after: Sequel.pg_json_wrap({ "foo3" => "bar3" }))
    num2 = nil
    num1 = fetcher.fetch_events do |event|
      # blocks group 2
      assert event[:type] == "event_created"
      assert event[:after] == { "foo" => "bar" }
      Thread.start do
        num2 = fetcher.fetch_events do |sec_event|
          # blocks group 1
          assert sec_event[:type] == "event_created"
          assert sec_event[:after] == { "foo3" => "bar3" }

          Thread.start do
            # all groups blocked
            events = fetcher.fetch_events
            assert events.empty?

            outbox_ds.insert(type: "event_created", group_id: 2,
                             data_after: Sequel.pg_json_wrap({ "foo4" => "bar4" }))
          end.join

          Thread.start do
            # new message in group 2, but they must remain blocked
            events = fetcher.fetch_events
            assert events.empty?
          end.join
        end
      end.join
    end

    assert num1 == 1
    assert num2 == 1
  end

  private

  def outbox_ds
    db[:outbox_with_group]
  end

  def fetcher
    @fetcher ||= Fetcher.new("test", make_configuration do |cfg|
      cfg.table :outbox_with_group
      yield(cfg)
    end)
  end

  def teardown
    outbox_ds.truncate
  end
end
