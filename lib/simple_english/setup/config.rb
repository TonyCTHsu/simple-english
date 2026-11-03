# frozen_string_literal: true

# .simple-english.yml: ignore (path globs, matched against the paths
# given on the command line), disabled-rules (rule IDs dropped
# from every file), and rule-ignores (a rule dropped only on the
# listed path globs, fired everywhere else). Loaded from the CWD.

module SimpleEnglish
  module Config
    ConfigError = Class.new(StandardError)
    DEFAULT = {ignore: [], disabled_rules: [], rule_ignores: {}}.freeze

    module_function

    def load(dir = Dir.pwd)
      file = File.join(dir, ".simple-english.yml")
      return DEFAULT unless File.exist?(file)
      require "yaml"
      data = YAML.safe_load_file(file) || {}
      {ignore: Array(data["ignore"]),
       disabled_rules: Array(data["disabled-rules"]),
       rule_ignores: load_rule_ignores(data["rule-ignores"])}
    rescue Psych::SyntaxError => e
      raise ConfigError, ".simple-english.yml: #{e.message}"
    end

    # Loose like the other keys: a rule ID with no entry means the
    # rule fires everywhere, so a wrong ID surfaces its findings
    # instead of hiding them.
    def load_rule_ignores(data)
      return {} unless data.is_a?(Hash)
      data.to_h { |rule, globs| [rule, Array(globs)] }
    end

    # Hooks pass absolute paths while ignore globs are written
    # relative to the repo root (the CWD). Match both forms.
    # realpath because CWD may be a symlink-resolved path while the
    # caller's string still carries the symlink (TMPDIR on macOS).
    def ignore?(config, path)
      path_matches?(config[:ignore], path)
    end

    def path_matches?(globs, path)
      candidates = [path, relative_candidate(path)].compact
      globs.any? do |pattern|
        candidates.any? { |candidate| matches?(pattern, candidate) }
      end
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

    # rule-ignores needs the finding's file, which findings do not
    # carry, so the caller passes path in. A nil path (stdin, MCP
    # text) has no path to match, so every rule fires.
    def filter(config, findings, path: nil)
      disabled = config[:disabled_rules]
      rule_ignores = config[:rule_ignores] || {}
      findings.reject do |finding|
        disabled.include?(finding.rule) ||
          (path && path_matches?(rule_ignores[finding.rule] || [], path))
      end
    end
  end
end
