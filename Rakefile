# frozen_string_literal: true

require "bundler/gem_tasks" # adds build / install / release tasks
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/test_*.rb"]
  t.warning = false
  t.verbose = false
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:lint)
rescue LoadError
  desc "Run the linter (rubocop not installed)"
  task :lint do
    warn "rubocop is not available; skipping lint"
  end
end

desc "Run tests and the linter"
task default: %i[test lint]
