# frozen_string_literal: true

require "bundler/gem_tasks"

task default: :test

desc "Run the unit tests"
task :test do
  ruby "test/run.rb"
end

desc "Lint prose and code comments with se"
task :lint do
  sh "bin/se ."
end

desc "Run everything CI runs"
task check: [:lint, :test] do
  ruby "test/examples_check.rb"
  ruby "test/corpus_check.rb"
end
