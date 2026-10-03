# frozen_string_literal: true

# Resolves the bundled native LanguageTool server once, at the process edge.
# Tests and source builds can select an explicit executable through the
# environment. Released platform gems provide the default under libexec.

require_relative "languagetool"

module SimpleEnglish
  class Install
    class SetupError < StandardError
    end

    attr_reader :executable

    def initialize(executable:)
      @executable = File.expand_path(executable)
    end

    def self.from_env(env = ENV)
      executable = env.fetch(LanguageTool::EXECUTABLE_ENV,
        LanguageTool::BUNDLED_EXECUTABLE)
      new(executable: executable)
    end

    def executable?
      File.file?(executable) && File.executable?(executable)
    end

    def executable!
      return executable if executable?
      raise SetupError, setup_error
    end

    def setup_error
      "lint engine not found or not executable at #{executable}. " \
        "Install a supported platform build of this gem."
    end
  end
end
