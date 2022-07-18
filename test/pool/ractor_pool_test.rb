# frozen_string_literal: true
return unless ENV["ENABLE_RACTOR_POOL_TESTS"]

require "test_helper"

class RactorPoolTest < DatabaseTest
  include Tobox

  def test_pool_init
    pool do |c|
      c.concurrency 2
      c.shutdown_timeout 1
      c.database_uri db.uri
    end

    ractors = pool.instance_variable_get(:@ractors)
    assert ractors.size == 2
    assert ractors.all? { |th| th.is_a?(Ractor) }
  end

  def test_pool_stop
    pool do |c|
      c.concurrency 2
      c.shutdown_timeout 1
    end
    assert pool.instance_variable_get(:@ractors).size == 2
    pool.stop
    assert pool.instance_variable_get(:@ractors).size == 0
  end
  private

  def pool
    @pool ||= begin
      conf = Configuration.new do |c|
        yield c if block_given?
      end
      RactorPool.new(conf)
    end
  end
end