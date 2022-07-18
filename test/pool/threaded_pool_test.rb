# frozen_string_literal: true

require "test_helper"

class ThreadedPoolTest < Minitest::Test
  include Tobox

  def test_pool_init
    pool do |c|
      c.concurrency 2
      c.shutdown_timeout 1
    end

    threads = pool.instance_variable_get(:@threads)
    assert threads.size == 2
    assert(threads.all? { |th| th.is_a?(Thread) })
  end

  def test_pool_stop
    pool do |c|
      c.concurrency 2
      c.shutdown_timeout 1
    end
    assert pool.instance_variable_get(:@threads).size == 2
    pool.stop
    assert pool.instance_variable_get(:@threads).size.zero?
  end

  private

  def pool
    @pool ||= begin
      conf = Configuration.new do |c|
        yield c if block_given?
      end
      ThreadedPool.new(conf)
    end
  end
end
