# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

begin
  require "rubocop/rake_task"
  desc "Run rubocop"
  RuboCop::RakeTask.new(:rubocop)
rescue LoadError
end

task default: %i[test]
