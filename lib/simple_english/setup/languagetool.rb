# frozen_string_literal: true

# Pinned LanguageTool facts shared by the native build and Ruby runtime.

module SimpleEnglish
  module LanguageTool
    RULES_FILE = File.expand_path("../../../rules/simple-english.xml", __dir__)
    LT_VERSION = "6.6"
    EXECUTABLE_ENV = "SE_LANGUAGETOOL_EXECUTABLE"
    BUNDLED_EXECUTABLE = File.expand_path(
      "../../../libexec/simple_english/languagetool-server", __dir__
    )
    TIMEOUT_SECONDS = 30

    module_function

    def rule_ids(path = RULES_FILE)
      File.read(path, encoding: "UTF-8").scan(/<(?:rule|rulegroup)\b[^>]*>/).filter_map do |tag|
        tag[/\bid="([^"]+)"/, 1]
      end
    end
  end
end
