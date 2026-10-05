#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "socket"
require "tempfile"
require "uri"

module NativeLanguageToolBuild
  module_function

  ROOT = Pathname(__dir__).join("../..").expand_path
  SOURCE = Pathname(__dir__).expand_path
  BUILD = ROOT.join("tmp/native-languagetool")
  TARGET = BUILD.join("maven-target")
  DEPENDENCIES_FILE = BUILD.join("dependencies.classpath")
  CLASSPATH_FILE = BUILD.join("classpath")
  EXECUTABLE = BUILD.join("languagetool-native")
  SBOM = Pathname("#{EXECUTABLE}.sbom.json")
  MAIN_CLASS = "org.languagetool.server.HTTPServer"

  def run
    prepare_classes
    FileUtils.rm_f([EXECUTABLE, SBOM])
    FileUtils.rm_f(Dir[BUILD.join("lib*.so")])
    build_executable
    abort "Native Image did not export #{SBOM}" unless SBOM.file?
    smoke_test
    puts "Built #{EXECUTABLE.relative_path_from(ROOT)}"
    Dir[BUILD.join("lib*.so")].sort.each do |library|
      puts "Built #{Pathname(library).relative_path_from(ROOT)}"
    end
  end

  # Native Image stamps the build host's OS version into the binary
  # unless the link pins an older floor. MACOSX_DEPLOYMENT_TARGET has no
  # effect: the compiler passes its own minimum flag, and this linker
  # option overrides it.
  def deployment_target_option
    return [] unless RbConfig::CONFIG["host_os"].include?("darwin")

    ["-H:NativeLinkerOption=-mmacosx-version-min=12.0"]
  end

  def prepare_classes
    FileUtils.rm_rf(TARGET)
    FileUtils.rm_f([DEPENDENCIES_FILE, CLASSPATH_FILE])
    FileUtils.mkdir_p(BUILD)
    build_classes
  end

  def build_classes
    system(
      ROOT.join("mvnw").to_s, "--batch-mode", "--no-transfer-progress",
      "-Dnative.build.directory=#{TARGET}",
      "-Dmdep.outputFile=#{DEPENDENCIES_FILE}",
      "-f", SOURCE.join("pom.xml").to_s,
      "process-resources", "dependency:build-classpath",
      exception: true
    )
    rules = TARGET.join("classes/org/languagetool/rules/en/grammar_custom.xml")
    FileUtils.mkdir_p(rules.dirname)
    FileUtils.cp(ROOT.join("rules/simple-english.xml"), rules)
    classpath = [TARGET.join("classes"), DEPENDENCIES_FILE.read.strip].join(File::PATH_SEPARATOR)
    CLASSPATH_FILE.write(classpath)
  end

  def native_image
    from_home = File.join(ENV.fetch("JAVA_HOME", ""), "bin", "native-image")
    return from_home if File.executable?(from_home)

    "native-image"
  end

  def build_executable
    options = ["--no-fallback", "--enable-sbom=embed,export"]
    # -march is an AMD64-only option. AArch64 has a single baseline.
    options << "-march=compatibility" if RbConfig::CONFIG["host_cpu"].match?(/x86_64|amd64/)
    options += deployment_target_option + [
      "--initialize-at-run-time=ch.qos.logback,org.slf4j,io.prometheus,io.opentelemetry,io.grpc.netty.shaded.io.netty",
      "--enable-url-protocols=http,https",
      "-H:ConfigurationFileDirectories=#{SOURCE.join("config")}"
    ]
    parallelism = ENV["NATIVE_IMAGE_PARALLELISM"]
    options << "--parallelism=#{parallelism}" if parallelism
    system(
      native_image, *options,
      "-cp", CLASSPATH_FILE.read.strip,
      MAIN_CLASS,
      EXECUTABLE.to_s,
      exception: true
    )
  end

  def smoke_test
    port = available_port
    log = Tempfile.new("languagetool-native")
    pid = Process.spawn(EXECUTABLE.to_s, "--port", port.to_s, out: log, err: log)
    wait_until_ready(port, pid, log)
    uri = URI("http://localhost:#{port}/v2/check")
    params = {
      "language" => "en",
      "enabledRules" => "SE_NO_CONTRACTIONS",
      "enabledOnly" => "true",
      "text" => "The worker didn't write the file."
    }
    responses = 2.times.map do
      response = Net::HTTP.post_form(uri, params)
      abort "Native smoke request failed: HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end
    abort "Persistent native smoke test failed" unless responses.uniq.one?
    ids = responses.first.fetch("matches").map { |match| match.dig("rule", "id") }
    abort "Native smoke test missed SE_NO_CONTRACTIONS" unless ids.include?("SE_NO_CONTRACTIONS")
  ensure
    Process.kill("TERM", pid) if pid
    Process.wait(pid) if pid
    log&.close!
  end

  def available_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  def wait_until_ready(port, pid, log)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
    loop do
      TCPSocket.open("127.0.0.1", port, &:close)
      return
    rescue Errno::ECONNREFUSED
      unless process_running?(pid)
        log.rewind
        abort "Native server exited during startup:\n#{log.read}"
      end
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        log.rewind
        abort "Native server did not start:\n#{log.read}"
      end
      sleep 0.1
    end
  end

  def process_running?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end
end

NativeLanguageToolBuild.run if $PROGRAM_NAME == __FILE__
