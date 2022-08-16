# frozen_string_literal: true

return unless ENV["ENABLE_FIBER_POOL_TESTS"]

require "test_helper"

class FiberPoolTest < Minitest::Test
  include Tobox

  def test_pool_stop
    pool do |c|
      c.concurrency 2
      c.shutdown_timeout 1
    end
    thread = pool.instance_variable_get(:@fiber_thread)
    assert thread.status != false
    pool.stop
    assert thread.status == false
  end

  private

  def pool
    @pool ||= begin
      conf = Configuration.new do |c|
        yield c if block_given?
        c.worker :fiber
      end
      app = Application.new(conf)
      app.start
      app.instance_variable_get(:@pool)
    end
  end
end
