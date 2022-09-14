# frozen_string_literal: true

require "test_helper"
require "logger"
require "zeitwerk"
require "tobox"

class ZeitwerkTest < DatabaseTest
  include Tobox

  def test_zeitwerk_loader_lifecycle
    File.write(File.join(__dir__, "x.rb"), "X = 1")

    ft = fetcher do |c|
      c.plugin(:zeitwerk)
      c.zeitwerk_loader do |loader|
        loader.push_dir(__dir__)
      end
    end

    cfg = ft.instance_variable_get(:@configuration)
    loader = cfg.zeitwerk_loader
    assert loader.dirs.include?(__dir__)
    assert loader.reloading_enabled?

    assert 1, X

    File.write(File.join(__dir__, "x.rb"), "X = 2")

    # run a reload cycle
    db[:outbox].insert(type: "event_created", data_after: Sequel.pg_json_wrap({ "foo" => "bar" }))
    return_value = fetcher.fetch_events { |_| }
    assert return_value == 1

    assert 2, X
  ensure
    FileUtils.rm(File.join(__dir__, "x.rb"))
  end

  private

  def fetcher(&blk)
    @fetcher ||= Fetcher.new("test", Configuration.new(&blk))
  end
end