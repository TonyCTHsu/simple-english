# frozen_string_literal: true

require "digest"
require "fileutils"
require_relative "lib/simple_english/version"

NATIVE_BUILD = "tmp/native-languagetool"
NATIVE_EXECUTABLE = "#{NATIVE_BUILD}/languagetool-native"
SUPPORTED_PLATFORMS = %w[arm64-darwin x86_64-linux aarch64-linux].freeze

# Rake's timestamp comparison decides when to recompile: the native build
# reruns only when an input is newer than the executable. CI caches the
# build directory and touches the restored executable. Without the touch,
# a fresh checkout stamps every input with a new mtime and forces a rebuild.
file NATIVE_EXECUTABLE =>
      FileList["native/languagetool/**/*", "rules/simple-english.xml", "Gemfile.lock", "mvnw"] do
  sh "bundle exec ruby native/languagetool/build.rb"
end

# The build host is the only source for the platform label. Native Image
# compiles for the host, so a label that disagrees with the host mislabels
# the gem. Gem::Platform.local carries a version suffix on some hosts
# (arm64-darwin-25), so compare the bare cpu-os form.
def native_platform
  local = Gem::Platform.local
  candidate = "#{local.cpu}-#{local.os}"
  SUPPORTED_PLATFORMS.include?(candidate) or
    abort "error: unsupported build host #{candidate}. Supported: #{SUPPORTED_PLATFORMS.join(", ")}"
  candidate
end

desc "Build the native lint engine and the platform gem"
task build: NATIVE_EXECUTABLE do
  platform = native_platform
  build = Pathname.new(NATIVE_BUILD)
  executable = build.join("languagetool-native")
  classpath = build.join("classpath").read.strip
  sh "bundle exec ruby native/languagetool/verify.rb #{classpath} #{executable}"

  FileUtils.mkdir_p("libexec/simple_english")
  FileUtils.install(executable, "libexec/simple_english/languagetool-server", mode: 0o755)
  # The SBOM ships beside the binary, so the gemspec glob carries it in
  # the gem and the tar.
  sbom = build.join("maven-target/bom.json")
  FileUtils.install(sbom, "libexec/simple_english/languagetool-server.sbom.json")
  FileUtils.mkdir_p("dist")
  tar = "dist/languagetool-server-#{platform}.tar.gz"
  sh "tar -C libexec -czf #{tar} simple_english"
  FileUtils.cp(sbom, "dist/languagetool-server-#{platform}.sbom.json")
  checksum = Digest::SHA256.file(tar).hexdigest
  File.write("#{tar}.sha256", "#{checksum}  #{File.basename(tar)}\n")

  gem = "dist/simple_english-#{SimpleEnglish::VERSION}-#{platform}.gem"
  Bundler.with_unbundled_env do
    sh({"SIMPLE_ENGLISH_GEM_PLATFORM" => platform},
      "gem build simple_english.gemspec --output #{gem}")
  end
end

task default: :test

desc "Run the unit tests"
task :test do
  ruby "test/run.rb"
end

desc "Lint prose and code comments with se"
task :lint do
  sh "bin/se ."
  sh "bin/lint-fragments"
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

    # The integration manifests pin their own versions, and the unit
    # tests hold them to SimpleEnglish::VERSION. A release that skips
    # them fails CI on the release branch.
    %w[
      integrations/claude-code/.claude-plugin/plugin.json
      integrations/codex/plugin.json
      integrations/cursor/plugin.json
      integrations/pi/package.json
    ].each do |manifest|
      body = File.read(manifest)
      rewritten = body.sub(/"version": "[^"]*"/, %("version": "#{version}"))
      abort "error: #{manifest} declares no version" if rewritten == body
      File.write(manifest, rewritten)
    end

    sh "bundle lock"
    puts "Release #{version} prepared. Review, then commit."
  end
end
