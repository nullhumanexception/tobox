# frozen_string_literal: true

require "timeout"
require "test_helper"

class ThreadedPoolTest < Minitest::Test
  include Tobox
  include WithTestLogger

  def test_pool_init
    pool do |c|
      c.concurrency 2
      c.shutdown_timeout 1
    end.start

    threads = pool.threads
    assert threads.size == 2
    assert(threads.all?(Thread))
  end

  def test_pool_stop
    pool do |c|
      c.concurrency 2
      c.shutdown_timeout 1
    end.start

    assert pool.threads.size == 2
    pool.stop
    assert pool.threads.empty?
  end

  def test_pool_kill_parent_when_worker_stop
    pool do |c|
      c.concurrency 2
    end

    workers = pool.workers.dup

    workers.each do |wk|
      wk.instance_eval do
        def work
          sleep(1)
          raise StandardError, "what the hell"
        end
      end
    end

    begin
      pool.start
      Timeout.timeout(5) do
        sleep(0.5) until (workers - pool.workers).size == 2

        assert pool.workers.size == 2
        assert pool.threads.size == 2
      end
    rescue Timeout::Error
      raise "pool didn't cleanly run"
    ensure
      pool.stop
    end

    # assert("what the hell", Thread.start do
    #   pool.instance_variable_set(:@parent_thread, Thread.current)
    #   pool.start
    #   begin
    #     sleep(3)
    #   rescue Interrupt => e
    #     e.message
    #   end
    # end.value)
  end

  private

  def pool
    @pool ||= begin
      conf = make_configuration do |c|
        yield c if block_given?
        c.worker :thread
      end
      app = Application.new(conf)
      pool = app.instance_variable_get(:@pool)
      pool.singleton_class.class_eval do
        attr_reader :workers, :threads
      end
      pool
    end
  end
end
