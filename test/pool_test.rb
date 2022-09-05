# frozen_string_literal: true

require "test_helper"

class PoolTest < Minitest::Test
  include Tobox
  include WithTestLogger

  def test_pool_init
    pool do |c|
      c.concurrency 2
    end

    workers = pool.instance_variable_get(:@workers)
    assert workers.size == 2
    assert(workers.all?(Worker))
  end

  def test_pool_stop
    pool do |c|
      c.concurrency 2
    end
    workers = pool.instance_variable_get(:@workers)
    assert(workers.none? { |wk| wk.instance_variable_get(:@finished) })
    pool.stop
    assert(workers.all? { |wk| wk.instance_variable_get(:@finished) })
  end

  private

  def pool
    @pool ||= begin
      conf = make_configuration do |c|
        yield c if block_given?
      end
      Class.new(Pool) do
        # noop
        def start; end
      end.new(conf)
    end
  end
end
