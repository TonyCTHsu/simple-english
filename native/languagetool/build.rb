#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "net/http"
require "open3"
require "pathname"
require "rbconfig"
require "uri"

module NativeLanguageToolBuild
  module_function

  MAVEN_VERSION = "3.9.16"
  MAVEN_URL = "https://archive.apache.org/dist/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.tar.gz"
  MAVEN_SHA512 = "831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6"
  GRAALVM_VERSION = "21.0.12+7.1"
  GRAALVM_DIRECTORY = "graalvm-jdk-#{GRAALVM_VERSION}"

  PLATFORMS = {
    "darwin-arm64" => {
      archive: "graalvm-jdk-21.0.12_macos-aarch64_bin.tar.gz",
      sha256: "a98948c3a1ad037fe2dde5c80b06b214a5f80c120d8fc2453d155508cf677beb",
      java_home: "#{GRAALVM_DIRECTORY}/Contents/Home",
      toolchain: [
        [["cc", "--version"], "Apple clang version 17.0.0 (clang-1700.6.4.2)"],
        [["ld", "-v"], "@(#)PROGRAM:ld PROJECT:ld-1230.1"],
        [["xcrun", "--show-sdk-version"], "26.2"]
      ]
    },
    "linux-x86_64" => {
      archive: "graalvm-jdk-21.0.12_linux-x64_bin.tar.gz",
      sha256: "b007ff64c425f85bbe0e686107044fba6ca5054a7e89271a473767f546aaddc1",
      java_home: GRAALVM_DIRECTORY,
      toolchain: [
        [["cc", "--version"], nil],
        [["ld", "--version"], nil],
        [["ldd", "--version"], nil]
      ]
    },
    "linux-arm64" => {
      archive: "graalvm-jdk-21.0.12_linux-aarch64_bin.tar.gz",
      sha256: "e37877e3a67cd5c7be6172e8e26ecae7e5b4c76dd78f1d34f880cb7b985ebfd8",
      java_home: GRAALVM_DIRECTORY,
      toolchain: [
        [["cc", "--version"], nil],
        [["ld", "--version"], nil],
        [["ldd", "--version"], nil]
      ]
    }
  }.freeze

  ROOT = Pathname(__dir__).join("../..").expand_path
  SOURCE = Pathname(__dir__).expand_path
  CACHE = Pathname(ENV.fetch("SE_NATIVE_BUILD_DIR", ROOT.join("tmp/native-languagetool").to_s)).expand_path
  DOWNLOADS = CACHE.join("downloads")
  DEPENDENCY_LOCK = SOURCE.join("dependencies.sha256")

  def run
    platform_name = host_platform
    platform = PLATFORMS[platform_name]
    abort "Unsupported platform #{platform_name}. Supported: #{PLATFORMS.keys.join(", ")}" if platform.nil?

    verify_native_toolchain(platform.fetch(:toolchain))
    paths = build_paths(platform_name, platform)
    FileUtils.mkdir_p(DOWNLOADS)

    maven_archive = download(
      MAVEN_URL,
      DOWNLOADS.join("apache-maven-#{MAVEN_VERSION}-bin.tar.gz"),
      Digest::SHA512,
      MAVEN_SHA512
    )
    graalvm_archive = download(
      "https://download.oracle.com/graalvm/21/archive/#{platform.fetch(:archive)}",
      DOWNLOADS.join(platform.fetch(:archive)),
      Digest::SHA256,
      platform.fetch(:sha256)
    )
    extract(maven_archive, paths.fetch(:build), paths.fetch(:maven_home))
    extract(graalvm_archive, paths.fetch(:build), paths.fetch(:java_home))
    FileUtils.rm_rf([paths.fetch(:maven_repository), paths.fetch(:maven_target)])
    FileUtils.rm_f(paths.fetch(:executable))

    environment = {
      "JAVA_HOME" => paths.fetch(:java_home).to_s,
      "LANG" => "C.UTF-8",
      "LC_ALL" => "C.UTF-8",
      "PATH" => "#{paths.fetch(:java_home).join("bin")}:#{ENV.fetch("PATH")}"
    }
    build_jar(environment, paths)
    verify_dependencies(paths.fetch(:maven_repository))
    build_executable(environment, paths)
    verify_executable(environment, paths)
    puts "Built #{paths.fetch(:executable)}"
  end

  def host_platform
    os = case RbConfig::CONFIG.fetch("host_os")
    when /darwin/
      "darwin"
    when /linux/
      "linux"
    else
      RbConfig::CONFIG.fetch("host_os")
    end
    machine = RbConfig::CONFIG.fetch("host_cpu")
    architecture = case machine
    when "aarch64", "arm64"
      "arm64"
    when "amd64", "x86_64"
      "x86_64"
    else
      machine
    end
    "#{os}-#{architecture}"
  end

  def build_paths(platform_name, platform)
    build = CACHE.join(platform_name)
    {
      build: build,
      maven_home: build.join("apache-maven-#{MAVEN_VERSION}"),
      java_home: build.join(platform.fetch(:java_home)),
      maven_repository: build.join("maven-repository"),
      maven_target: build.join("maven-target"),
      executable: build.join("languagetool-native")
    }
  end

  def verify_native_toolchain(checks)
    checks.each do |command, expected|
      stdout, stderr, status = Open3.capture3(*command)
      abort "Cannot run #{command.join(" ")}: #{stderr}" unless status.success?

      actual = "#{stdout}#{stderr}".lines.first&.strip
      next if expected.nil? || actual == expected

      abort "Expected #{expected.inspect} from #{command.join(" ")}, got #{actual.inspect}"
    rescue Errno::ENOENT
      abort "Missing native build tool: #{command.first}"
    end
  end

  def build_jar(environment, paths)
    command = [
      paths.fetch(:maven_home).join("bin/mvn").to_s,
      "--batch-mode", "--no-transfer-progress",
      "-Dmaven.repo.local=#{paths.fetch(:maven_repository)}",
      "-Dnative.build.directory=#{paths.fetch(:maven_target)}",
      "-f", SOURCE.join("pom.xml").to_s,
      "package"
    ]
    system(environment, *command, exception: true)
  end

  def build_executable(environment, paths)
    jar = paths.fetch(:maven_target).join("languagetool-native-0.1.0.jar")
    system(
      environment,
      paths.fetch(:java_home).join("bin/native-image").to_s,
      "--no-fallback",
      "-march=compatibility",
      "--initialize-at-build-time=org.slf4j",
      "--enable-url-protocols=https",
      "-H:ConfigurationFileDirectories=#{SOURCE.join("config")}",
      "-jar", jar.to_s,
      paths.fetch(:executable).to_s,
      exception: true
    )
  end

  def verify_executable(environment, paths)
    system(
      environment,
      RbConfig.ruby,
      SOURCE.join("verify.rb").to_s,
      paths.fetch(:maven_target).join("languagetool-native-0.1.0.jar").to_s,
      paths.fetch(:executable).to_s,
      exception: true
    )
  end

  def download(url, destination, digest_class, expected)
    return destination if destination.file? && checksum(destination, digest_class) == expected

    FileUtils.rm_f(destination)
    temporary = Pathname("#{destination}.part")
    FileUtils.rm_f(temporary)
    fetch(URI(url), temporary)
    actual = checksum(temporary, digest_class)
    abort "Checksum mismatch for #{url}: expected #{expected}, got #{actual}" unless actual == expected

    FileUtils.mv(temporary, destination)
    destination
  end

  def fetch(uri, destination, redirects = 5)
    abort "Too many redirects while downloading #{uri}" if redirects.zero?

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request_get(uri.request_uri) do |response|
        if response.is_a?(Net::HTTPRedirection)
          location = response["location"]
          abort "Redirect from #{uri} has no location" if location.nil?

          return fetch(URI.join(uri.to_s, location), destination, redirects - 1)
        end
        response.value
        destination.open("wb") { |file| response.read_body { |chunk| file.write(chunk) } }
      end
    end
  end

  def checksum(path, digest_class)
    digest = digest_class.new
    path.open("rb") do |file|
      digest << file.read(1024 * 1024) until file.eof?
    end
    digest.hexdigest
  end

  def extract(archive, directory, expected_path)
    return if expected_path.exist?

    FileUtils.mkdir_p(directory)
    system("tar", "-xzf", archive.to_s, "-C", directory.to_s, exception: true)
    abort "Archive did not contain #{expected_path}" unless expected_path.exist?
  end

  def verify_dependencies(repository)
    actual = dependency_checksums(repository)
    if ENV["UPDATE_DEPENDENCY_LOCK"] == "1"
      DEPENDENCY_LOCK.write(actual)
      puts "Updated #{DEPENDENCY_LOCK.relative_path_from(ROOT)}"
      return
    end

    abort "Missing #{DEPENDENCY_LOCK.relative_path_from(ROOT)}" unless DEPENDENCY_LOCK.file?
    return if DEPENDENCY_LOCK.read == actual

    abort "Maven dependency checksums differ from #{DEPENDENCY_LOCK.relative_path_from(ROOT)}"
  end

  def dependency_checksums(repository)
    paths = repository.glob("**/*").select { |path| path.file? && %w[.jar .pom].include?(path.extname) }
    paths.sort.map do |path|
      relative = path.relative_path_from(repository)
      "#{checksum(path, Digest::SHA256)}  #{relative}\n"
    end.join
  end
end

NativeLanguageToolBuild.run if $PROGRAM_NAME == __FILE__
