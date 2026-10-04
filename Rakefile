# frozen_string_literal: true

require "fileutils"
require_relative "lib/simple_english/version"

desc "Build the native lint engine and the platform gem. Set PLATFORM=x86_64-linux"
task :build do
  platform = ENV["PLATFORM"] or
    abort "error: set PLATFORM, for example PLATFORM=x86_64-linux rake build"
  build = Pathname.new("tmp/native-languagetool")
  executable = build.join("languagetool-native")
  sbom = build.join("languagetool-native.sbom.json")
  # CI restores a binary cached on the build inputs. Verification, packaging,
  # and the gem build always rerun against the restored binary.
  cached = ENV["NATIVE_CACHE_HIT"] == "true" && executable.executable? && sbom.file?
  sh "bundle exec ruby native/languagetool/build.rb" unless cached
  classpath = build.join("classpath").read.strip
  sh "bundle exec ruby native/languagetool/verify.rb #{classpath} #{executable}"

  FileUtils.mkdir_p("libexec/simple_english")
  FileUtils.install(executable, "libexec/simple_english/languagetool-server", mode: 0o755)
  FileUtils.mkdir_p("dist")
  tar = "dist/languagetool-server-#{platform}.tar.gz"
  sh "tar -C libexec -czf #{tar} simple_english"
  FileUtils.cp(sbom, "dist/languagetool-server-#{platform}.sbom.json")
  checksum = Digest::SHA256.file(tar).hexdigest
  File.write("#{tar}.sha256", "#{checksum}  #{File.basename(tar)}\n")

  gem = "dist/simple_english-#{SimpleEnglish::VERSION}-#{platform}.gem"
  sh({"SIMPLE_ENGLISH_GEM_PLATFORM" => platform},
    "gem build simple_english.gemspec --output #{gem}")
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
    sh "bundle lock"
    puts "Release #{version} prepared. Review, then commit."
  end
end
