#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"
require "rbconfig"

require_relative "build"

module NativeLanguageToolMetadata
  module_function

  ROOT = NativeLanguageToolBuild::ROOT
  BUILD = NativeLanguageToolBuild::BUILD
  OUTPUT = BUILD.join("agent-metadata")
  GENERATED = OUTPUT.join("reachability-metadata.json")
  TRACKED = NativeLanguageToolBuild::SOURCE.join("config/reachability-metadata.json")
  VERIFY = NativeLanguageToolBuild::SOURCE.join("verify.rb")

  def run(check: false)
    abort "JAVA_HOME must select GraalVM" unless ENV["JAVA_HOME"]

    NativeLanguageToolBuild.prepare_classes
    FileUtils.rm_rf(OUTPUT)
    FileUtils.mkdir_p(OUTPUT)
    agent = "-agentlib:native-image-agent=config-output-dir=#{OUTPUT}"
    jvm_options = [
      agent,
      "-Duser.language=en",
      "-Duser.country=",
      "-Duser.variant=",
      "-Duser.timezone=UTC"
    ]
    system(
      {"SE_VERIFY_JVM_OPTIONS" => JSON.generate(jvm_options)},
      RbConfig.ruby, VERIFY.to_s,
      NativeLanguageToolBuild::CLASSPATH_FILE.read.strip,
      exception: true
    )
    validate_generated

    if check
      abort stale_message unless FileUtils.compare_file(GENERATED, TRACKED)
      puts "Reachability metadata is current"
    else
      FileUtils.cp(GENERATED, TRACKED)
      puts "Updated #{TRACKED.relative_path_from(ROOT)}"
    end
  end

  def validate_generated
    metadata = JSON.parse(GENERATED.read)
    abort "Tracing agent generated no reflection metadata" unless metadata["reflection"]&.any?
    abort "Tracing agent generated no resource metadata" unless metadata["resources"]&.any?
  rescue Errno::ENOENT, JSON::ParserError => e
    abort "Invalid tracing-agent output at #{GENERATED}: #{e.message}"
  end

  def stale_message
    "Reachability metadata is stale. Run: ruby native/languagetool/metadata.rb\n" \
      "Generated candidate: #{GENERATED}"
  end
end

if $PROGRAM_NAME == __FILE__
  unknown = ARGV - ["--check"]
  abort "usage: metadata.rb [--check]" unless unknown.empty? && ARGV.count("--check") <= 1
  NativeLanguageToolMetadata.run(check: ARGV.include?("--check"))
end
