# frozen_string_literal: true

# .simple-english.yml: ignore (path globs, matched against the paths given
# on the command line), disabled-rules, and rules (LanguageTool XML
# files merged into the built-in rule set). Loaded from the CWD.

module SimpleEnglish
  module Config
    ConfigError = Class.new(StandardError)
    DEFAULT = {ignore: [], disabled_rules: [], rules: []}.freeze

    module_function

    def load(dir = Dir.pwd)
      file = File.join(dir, ".simple-english.yml")
      return DEFAULT unless File.exist?(file)
      require "yaml"
      data = YAML.safe_load_file(file) || {}
      rules = Array(data["rules"]).map do |path|
        unless path.is_a?(String) && !path.strip.empty?
          raise ConfigError, ".simple-english.yml: rules entries must be file paths"
        end
        expanded = File.expand_path(path, dir)
        unless File.file?(expanded)
          raise ConfigError, ".simple-english.yml: rules file not found: #{expanded}"
        end
        expanded
      end
      {ignore: Array(data["ignore"]),
       disabled_rules: Array(data["disabled-rules"]),
       rules: rules}
    rescue Psych::SyntaxError => e
      raise ConfigError, ".simple-english.yml: #{e.message}"
    end

    def ignore?(config, path)
      config[:ignore].any? { |pattern| matches?(pattern, path) }
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
