#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "pathname"

module NativeLanguageToolBuild
  module_function

  ROOT = Pathname(__dir__).join("../..").expand_path
  SOURCE = Pathname(__dir__).expand_path
  BUILD = ROOT.join("tmp/native-languagetool")
  TARGET = BUILD.join("maven-target")
  DEPENDENCIES_FILE = BUILD.join("dependencies.classpath")
  CLASSPATH_FILE = BUILD.join("classpath")
  EXECUTABLE = BUILD.join("languagetool-native")

  def run
    FileUtils.rm_rf(TARGET)
    FileUtils.rm_f([DEPENDENCIES_FILE, CLASSPATH_FILE, EXECUTABLE])
    FileUtils.mkdir_p(BUILD)
    build_classes
    build_executable
    smoke_test
    puts "Built #{EXECUTABLE.relative_path_from(ROOT)}"
  end

  def build_classes
    system(
      "mvn", "--batch-mode", "--no-transfer-progress",
      "-Dnative.build.directory=#{TARGET}",
      "-Dmdep.outputFile=#{DEPENDENCIES_FILE}",
      "-f", SOURCE.join("pom.xml").to_s,
      "compile", "dependency:build-classpath",
      exception: true
    )
    classpath = [TARGET.join("classes"), DEPENDENCIES_FILE.read.strip].join(File::PATH_SEPARATOR)
    CLASSPATH_FILE.write(classpath)
  end

  def build_executable
    classpath = CLASSPATH_FILE.read.strip
    system(
      "native-image",
      "--no-fallback",
      "-march=compatibility",
      "--initialize-at-build-time=org.slf4j",
      "--enable-url-protocols=https",
      "-H:ConfigurationFileDirectories=#{SOURCE.join("config")}",
      "-cp", classpath,
      "org.simpleenglish.NativeLanguageTool",
      EXECUTABLE.to_s,
      exception: true
    )
  end

  def smoke_test
    request = JSON.generate("text" => "The worker didn't write the file.")
    Open3.popen3(EXECUTABLE.to_s) do |input, output, error, wait|
      2.times { input.puts(request) }
      input.close
      responses = 2.times.map do
        response = output.gets
        abort error.read if response.nil?
        JSON.parse(response)
      end
      stderr = error.read
      abort stderr unless wait.value.success? && stderr.empty?
      abort "Persistent native smoke test failed" unless responses.uniq.one?
      ids = responses.first.fetch("matches").map { |match| match.dig("rule", "id") }
      abort "Native smoke test missed SE_NO_CONTRACTIONS" unless ids.include?("SE_NO_CONTRACTIONS")
    end
  end
end

NativeLanguageToolBuild.run if $PROGRAM_NAME == __FILE__
