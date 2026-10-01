# frozen_string_literal: true

# The resolved LanguageTool installation: where the jars live and which
# java runs them. Build it once from the environment at the process
# edge with Install.from_env. Everything downstream takes the value,
# never the environment. A nil java means "not found": ask with java?
# or fail with java! and get the fix in the message.

require_relative "languagetool"

module SimpleEnglish
  class Install
    class SetupError < StandardError
    end

    attr_reader :cache_dir, :java, :java_source

    def initialize(cache_dir:, java: nil, java_source: nil)
      @cache_dir = cache_dir
      @java = java
      @java_source = java_source
    end

    # The one place the environment is read. SE_JAVA wins outright,
    # because the user asserted it and nobody re-probes an override.
    # Otherwise the code probes the PATH candidate by running it,
    # because a file can exist and still be the macOS stub that
    # reports no runtime. The last resort is the Homebrew location,
    # which sits outside PATH. java_source records which of the three
    # won, so `se setup` can say so.
    def self.from_env(env = ENV)
      cache = File.expand_path(env.fetch(LanguageTool::CACHE_DIR_ENV) do
        File.join(Dir.home, ".cache", "se")
      end)
      java, source =
        if (explicit = env[LanguageTool::JAVA_ENV])
          [explicit, :env]
        elsif probe?("java", env)
          ["java", :path]
        elsif File.executable?(LanguageTool::HOMEBREW_JAVA)
          [LanguageTool::HOMEBREW_JAVA, :homebrew]
        end
      new(cache_dir: cache, java: java, java_source: source)
    end

    # Runs the candidate under the given PATH, isolated from this
    # process's own PATH so tests can probe a fake environment.
    def self.probe?(candidate, env)
      system({"PATH" => env.fetch("PATH", "")}, candidate, "-version",
        out: File::NULL, err: File::NULL)
    end
    private_class_method :probe?

    def java?
      !java.nil?
    end

    def java!
      return java if java?
      raise SetupError, java_message
    end

    def java_message
      "java not found. Install a JRE (on macOS: brew install openjdk), " \
        "or set SE_JAVA to your java binary."
    end

    def lt_dir
      File.join(cache_dir, "LanguageTool-#{LanguageTool::LT_VERSION}")
    end

    def commandline_jar
      File.join(lt_dir, "languagetool-commandline.jar")
    end

    def server_jar
      File.join(lt_dir, "languagetool-server.jar")
    end

    def setup_error
      "LanguageTool #{LanguageTool::LT_VERSION} not found at #{server_jar}. " \
        "This gem pins that version. Run `se setup`."
    end
  end
end
