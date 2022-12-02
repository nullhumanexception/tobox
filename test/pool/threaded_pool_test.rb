# frozen_string_literal: true

require "test_helper"

class ThreadedPoolTest < Minitest::Test
  include Tobox
  include WithTestLogger

  def test_pool_init
    pool do |c|
      c.concurrency 2
      c.shutdown_timeout 1
    end

    threads = pool.instance_variable_get(:@threads)
    assert threads.size == 2
    assert(threads.all?(Thread))
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

  def test_pool_kill_parent_when_worker_stop
    pool do |c|
      c.concurrency 2
    end
    pool.instance_variable_get(:@workers).each do |wk|
      wk.instance_eval do
        def work
          sleep(1)
          raise StandardError, "what the hell"
        end
      end
    end

    assert("what the hell", Thread.start do
      pool.instance_variable_set(:@parent_thread, Thread.current)
      pool.start
      begin
        sleep(3)
      rescue Interrupt => e
        e.message
      end
    end.value)
  end

  private

  def pool
    @pool ||= begin
      conf = make_configuration do |c|
        yield c if block_given?
        c.worker :thread
      end
      app = Application.new(conf)
      app.start
      app.instance_variable_get(:@pool)
    end
  end
end
