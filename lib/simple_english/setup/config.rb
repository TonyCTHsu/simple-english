# frozen_string_literal: true

# .simple-english.yml: ignore (path globs, matched against the paths
# given on the command line) and disabled-rules (rule IDs dropped
# from every file). Loaded from the CWD.

module SimpleEnglish
  module Config
    ConfigError = Class.new(StandardError)
    DEFAULT = {ignore: [], disabled_rules: []}.freeze

    module_function

    def load(dir = Dir.pwd)
      file = File.join(dir, ".simple-english.yml")
      return DEFAULT unless File.exist?(file)
      require "yaml"
      data = YAML.safe_load_file(file) || {}
      {ignore: Array(data["ignore"]),
       disabled_rules: Array(data["disabled-rules"])}
    rescue Psych::SyntaxError => e
      raise ConfigError, ".simple-english.yml: #{e.message}"
    end

    # Hooks pass absolute paths while ignore globs are written
    # relative to the repo root (the CWD). Match both forms.
    # realpath because CWD may be a symlink-resolved path while the
    # caller's string still carries the symlink (TMPDIR on macOS).
    def ignore?(config, path)
      candidates = [path, relative_candidate(path)].compact
      candidates.any? { |candidate| config[:ignore].any? { |pattern| matches?(pattern, candidate) } }
    end

    def relative_candidate(path)
      pwd = Dir.pwd + "/"
      resolved = File.exist?(path) ? File.realpath(path) : File.expand_path(path)
      resolved.start_with?(pwd) ? resolved.delete_prefix(pwd) : nil
    end

    # File.fnmatch has no globstar: `**` never crosses directories.
    # Translate instead: `**` as a whole segment is any depth, `*` and
    # `?` stay within one segment.
    def matches?(pattern, path)
      glob_to_regex(pattern).match?(path)
    end

    def glob_to_regex(pattern)
      Regexp.new("\\A" + pattern.split("/").map do |segment|
        if segment == "**"
          "(?:[^/]+/)*[^/]*"
        else
          Regexp.escape(segment).gsub("\\*", "[^/]*").gsub("\\?", "[^/]")
        end
      end.join("/") + "\\z")
    end

    def filter(config, path, findings)
      return [] if ignore?(config, path)
      disabled = config[:disabled_rules]
      findings.reject { |finding| disabled.include?(finding.rule) }
    end
  end
end
