# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "integration tests for third party modules"
Rake::TestTask.new(:integration_tests) do |t|
  t.libs = %w[lib test]
  t.pattern = "integration_tests/**/*_test.rb"
  t.warning = false
end

begin
  require "rubocop/rake_task"
  desc "Run rubocop"
  RuboCop::RakeTask.new(:rubocop)
rescue LoadError
end

namespace :coverage do
  desc "Aggregates coverage reports"
  task :report do
    return unless ENV.key?("CI")

    require "simplecov"

    SimpleCov.collate Dir["coverage/**/.resultset.json"]
  end
end

task default: %i[test]
