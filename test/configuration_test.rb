# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  include Tobox

  def test_alias_config_methods
    assert configuration[:table] == :outbox
    configuration.table(:doubtbox)
    assert configuration[:table] == :doubtbox
    assert_raises do
      conf = Configuration.new {}
      conf.table(:doubtbox)
    end

    conf2 = Configuration.new { |c| c.table(:doubtbox) }
    assert conf2[:table] == :doubtbox

    conf3 = Configuration.new { table(:doubtbox) }
    assert conf3[:table] == :doubtbox

    assert_raises(NoMethodError) { Configuration.new { |c| c.smth(:doubtbox) } }
  end

  def test_handlers
    conf = Configuration.new do
      on(:resource_created) { 1 }
      on_resource_created { 2 }
      on(:resource_updated) { 3 }
      on_resource_updated { 3 }
    end
    assert conf.handlers.size == 2
    assert conf.handlers[:resource_created].size == 2
    assert conf.handlers[:resource_updated].size == 2
  end

  def test_event_callbacks
    conf = Configuration.new do
      on_before_event { 1 }
      on_after_event { 2 }
      on_error_event { 3 }
    end
    assert conf.lifecycle_events.size == 3
    assert conf.lifecycle_events[:before_event].size == 1
    assert conf.lifecycle_events[:after_event].size == 1
    assert conf.lifecycle_events[:error_event].size == 1
  end

  private

  def configuration(&blk)
    @configuration ||= Configuration.new(&blk)
  end
end
