# frozen_string_literal: true

require_relative "lib/simple_english"

Gem::Specification.new do |spec|
  spec.name = "simple_english"
  spec.version = SimpleEnglish::VERSION
  spec.authors = ["TonyCTHsu"]
  spec.summary = "Lint Markdown prose with the SimpleEnglish Plain-mode rules"
  spec.description = "Pattern rules run on LanguageTool, counting rules in " \
    "Ruby. Lints Markdown and code comments."
  spec.homepage = "https://github.com/TonyCTHsu/simple-english"
  spec.license = "MIT"
  spec.requirements = ["Java 11 or newer (`se setup` locates it)"]

  spec.files = Dir["lib/**/*.rb"] + Dir["rules/*.xml"] +
    ["bin/se", "LICENSE", "README.md", "docs/RULES.md"]
  spec.bindir = "bin"
  spec.executables = ["se"]

  spec.add_runtime_dependency "tree_sitter_language_pack", "~> 1.20"
  spec.add_runtime_dependency "thor", "~> 1.0"
  # rubyzip unpacks the LanguageTool download, replacing the curl/unzip
  # system dependencies.
  spec.add_runtime_dependency "rubyzip", "~> 3.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 6.0"

  # Bundled gems the suite requires under `bundle exec`: the require
  # shim refuses bundled gems that the lockfile omits.
  spec.add_development_dependency "json"
  spec.add_development_dependency "rexml"
end
