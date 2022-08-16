# frozen_string_literal: true

require "timeout"
require "test_helper"

class WorkerTest < DatabaseTest
  include Tobox

  def test_do_work_sleeps_on_it
    worker = Worker.new(Configuration.new { wait_for_events_delay(2) })

    # checks it sleeps on it
    time_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    worker.send(:do_work)
    assert_in_delta(Process.clock_gettime(Process::CLOCK_MONOTONIC) - time_now, 2, 0.5)

    # checks it doesn't sleep on it
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    time_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    worker.send(:do_work)
    assert_in_delta(Process.clock_gettime(Process::CLOCK_MONOTONIC) - time_now, 0, 0.5)
  end

  def test_do_work_calls_right_callback
    created = []
    configuration = Configuration.new do
      on(:event_created) { |_, after| created << after }
    end
    worker = Worker.new(configuration)
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    db[:outbox].insert(type: "event_updated", data_after: Sequel.pg_json_wrap({ "foo2" => "bar2" }))

    # consume both
    worker.send(:do_work)
    worker.send(:do_work)

    assert created.size == 1
    msg = created.first
    assert msg == { "foo" => "bar" }
  end

  def test_do_work_message_to_arguments
    created = []
    updated = []
    configuration = Configuration.new do
      message_to_arguments do |event_type, before, after|
        case event_type
        when :event_created
          :random_object
        else
          super(event_type, before, after)
        end
      end
      on(:event_created) { |obj| created << obj }
      on(:event_updated) { |*data| updated << data }
    end
    worker = Worker.new(configuration)
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    db[:outbox].insert(type: "event_updated", data_before: Sequel.pg_json_wrap({ "foo" => "bar" }),
                       data_after: Sequel.pg_json_wrap({ "foo2" => "bar2" }))

    # consume both
    worker.send(:do_work)
    worker.send(:do_work)

    assert created.size == 1
    msg = created.first
    assert msg == :random_object

    assert updated.size == 1
    msg = updated.first
    msg == [{ "foo" => "bar" }, { "foo2" => "bar2" }]
  end

  def test_do_work_stops_working
    created = []
    configuration = Configuration.new do
      wait_for_events_delay 1
      on(:event_created) { |_, after| created << after }
    end
    worker = Worker.new(configuration)
    worker.finish!
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))

    Timeout.timeout(2) { worker.work }

    assert created.empty?
  end
end
