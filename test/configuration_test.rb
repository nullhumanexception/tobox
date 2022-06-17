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
    conf = Configuration.new {
      on(:resource_created) { 1 }
      on(:resource_created) { 2 }
      on(:resource_updated) { 3 }
    }
    assert conf.handlers.size == 2
    assert conf.handlers[:resource_created].size == 2
    assert conf.handlers[:resource_updated].size == 1
  end

  private

  def configuration(&blk)
    @configuration ||= Configuration.new(&blk)
  end
end