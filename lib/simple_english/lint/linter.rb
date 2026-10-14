# frozen_string_literal: true

module SimpleEnglish
  module Linter
    module_function

    def lint_file(path, config: Config.load)
      return [] if Config.ignore?(config, path) || !Extractor.lintable?(path)
      lint_text(File.read(path, encoding: "UTF-8"), language: Extractor.language_for(path), config: config)
    end

    def lint_text(text, language: nil, config: Config.load)
      findings = SimpleEnglish.lint(text, language: language)
      findings && Config.filter(config, findings)
    end
  end
end
