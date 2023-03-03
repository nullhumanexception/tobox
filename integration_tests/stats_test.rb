# frozen_string_literal: true

require "test_helper"

class StatsTest < DatabaseTest
  include Tobox

  def test_stats_collect
    stats = []
    fetcher do |c|
      c.plugin(:stats)
      c.on_stats(1) do |st|
        stats << st
      end
      c.max_attempts 2

    end
    c = fetcher.instance_variable_get(:@configuration)
    Array(c.lifecycle_events[:on_start]).each(&:call)

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    sleep 1.2
    assert_equal 1, stats.size

    fetcher.fetch_events { |_| }
    sleep 1.2
    assert_equal 2, stats.size

    # with event
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    return_value = fetcher.fetch_events { |_|
      raise ZeroDivisionError, 'job error'
    }
    sleep 1.2
    assert_equal 3, stats.size

    return_value = fetcher.fetch_events { |_|
      raise ZeroDivisionError, 'job error'
    }
    sleep 1.2
    assert_equal 4, stats.size

    assert stats[0] == { pending_count: 1, failing_count: 0, failed_count: 0 }
    assert stats[1] == { pending_count: 0, failing_count: 0, failed_count: 0 }
    assert stats[2] == { pending_count: 0, failing_count: 1, failed_count: 0 }
    assert stats[3] == { pending_count: 0, failing_count: 0, failed_count: 1 }
  end

  private

  def fetcher(&blk)
    @fetcher ||= Fetcher.new("test", Configuration.new(&blk))
  end

  def teardown
    th = Thread.list.find do |t|
      t.name == "outbox-stats"
    end

    th.kill if th
  end
end