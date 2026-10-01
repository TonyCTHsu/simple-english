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

namespace :release do
  desc "Fold the change fragments into a release. Usage: rake 'release:prepare[0.1.1]'
 The version comes from `changie next auto` unless you pass one."
  task :prepare, [:version] do |_t, args|
    abort "error: changie is missing. Install it with `brew install changie`." unless
      system("changie --version", out: File::NULL, err: File::NULL)
    abort "error: no change fragments. Run `changie new` first." if Dir[".changes/unreleased/*.yaml"].empty?

    version = args[:version].to_s.empty? ? `changie next auto`.chomp : args[:version]
    abort "error: #{version} is not a X.Y.Z version" unless version.match?(/\A\d+\.\d+\.\d+\z/)

    version_file = "lib/simple_english/version.rb"
    source = File.read(version_file)
    current = source[/VERSION = "([^"]+)"/, 1]
    abort "error: VERSION is already #{current}" if current == version
    abort "error: .changes/#{version}.md already exists" if File.exist?(".changes/#{version}.md")

    sh "changie batch #{version}"
    sh "changie merge"
    File.write(version_file, source.sub(/VERSION = "[^"]+"/, %(VERSION = "#{version}")))
    sh "bundle lock"
    puts "Release #{version} prepared. Review, then commit."
  end
end

desc "Self-lint, unit-test, and run the rule examples"
task check: [:lint, :test] do
  ruby "test/examples_check.rb"
end
