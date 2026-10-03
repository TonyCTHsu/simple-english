# frozen_string_literal: true

require_relative "lib/simple_english"

Gem::Specification.new do |spec|
  spec.name = "simple_english"
  spec.version = SimpleEnglish::VERSION
  spec.authors = ["TonyCTHsu"]
  spec.summary = "Lint Markdown prose with the SimpleEnglish Plain-mode rules"
  spec.description = "Lints Markdown prose and code comments with pattern " \
    "and counting rules."
  spec.homepage = "https://github.com/TonyCTHsu/simple-english"
  spec.license = "MIT"
  spec.platform = ENV.fetch("SIMPLE_ENGLISH_GEM_PLATFORM", Gem::Platform::RUBY)
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md"
  }

  spec.files = Dir["lib/**/*.rb"] + Dir["libexec/**/*"] + Dir["rules/*.xml"] +
    Dir["licenses/**/*"] +
    ["bin/se", "LICENSE", "THIRD_PARTY_NOTICES.md", "README.md", "docs/RULES.md"]
  spec.bindir = "bin"
  spec.executables = ["se"]

  spec.add_runtime_dependency "tree_sitter_language_pack", "~> 1.20"
  spec.add_runtime_dependency "thor", "~> 1.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 6.0"
  spec.add_development_dependency "minitest-mock", "~> 5.27"

  # Bundled gems the suite requires under `bundle exec`: the require
  # shim refuses bundled gems that the lockfile omits.
  spec.add_development_dependency "json"
  spec.add_development_dependency "rexml"
end
