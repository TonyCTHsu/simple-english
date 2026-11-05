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
      if executable != LanguageTool::BUNDLED_EXECUTABLE
        "#{LanguageTool::EXECUTABLE_ENV} points at a missing or " \
          "non-executable file: #{executable}"
      elsif File.directory?(File.dirname(executable))
        "the lint engine is missing or not executable at " \
          "#{executable}; reinstall the gem"
      else
        "this copy ships no lint engine: a source checkout and the " \
          "plain gem both do. Install a platform build of the gem, or " \
          "point #{LanguageTool::EXECUTABLE_ENV} at a languagetool-server " \
          "binary."
      end
    end
  end
end
