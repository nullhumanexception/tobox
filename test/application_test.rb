# frozen_string_literal: true

require "test_helper"

class ApplicationTest < Minitest::Test
  include Tobox
  include WithTestLogger

  def test_start_stop
    worker_init = Class.new do
      attr_reader :commands

      def initialize(_cfg)
        @commands = []
        super()
      end

      def start
        @commands << :start
      end

      def stop
        @commands << :stop
      end
    end
    app = application do |c|
      c.worker worker_init
    end

    app.start
    pool = app.instance_variable_get(:@pool)
    assert pool.commands == %i[start]
    app.start
    assert pool.commands == %i[start]

    app.stop
    assert pool.commands == %i[start stop]
    app.stop
    assert pool.commands == %i[start stop]
  end

  private

  def application(&blk)
    @application ||= Application.new(make_configuration(&blk))
  end
end
