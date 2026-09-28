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
  desc "Bump the version and move the Unreleased entries into a dated
 heading. Usage: rake 'release:prepare[0.1.1]'"
  task :prepare, [:version] do |_t, args|
    version = args[:version] || abort("usage: rake 'release:prepare[0.1.1]'")
    abort "error: #{version} is not a X.Y.Z version" unless version.match?(/\A\d+\.\d+\.\d+\z/)

    version_file = "lib/simple_english/version.rb"
    source = File.read(version_file)
    current = source[/VERSION = "([^"]+)"/, 1]
    abort "error: VERSION is already #{current}" if current == version

    changelog = File.read("CHANGELOG.md")
    abort "error: CHANGELOG.md already holds #{version}" if changelog.include?("## [#{version}]")
    unreleased = changelog.split("## [Unreleased]", 2).fetch(1).split(/^## /, 2).first
    abort "error: Unreleased is empty. Add entries before you prepare a release." unless unreleased.match?(/^- /m)

    File.write(version_file, source.sub(/VERSION = "[^"]+"/, %(VERSION = "#{version}")))
    File.write("CHANGELOG.md", changelog.sub(
      "## [Unreleased]",
      "## [Unreleased]\n\n## [#{version}] - #{Time.now.strftime("%Y-%m-%d")}"
    ))
    puts "Release #{version} prepared. Review, then commit."
  end
end

desc "Run everything CI runs"
task check: [:lint, :test] do
  ruby "test/examples_check.rb"
  ruby "test/corpus_check.rb"
end
