# frozen_string_literal: true

# The command-line interface: Thor commands for lint, serve, and
# setup. bin/se is a thin runner over this, so the installed
# gem's RubyGems shim can load it.

require "thor"
require_relative "../simple_english"

module SimpleEnglish
  class CLI < Thor
    def self.exit_on_failure? = true

    # Bare file arguments and "-" (stdin) are lint targets, not command
    # names. Thor only falls back to the default task when the first
    # argument is an option, so route them to lint explicitly.
    def self.start(given_args = ARGV, config = {})
      first = given_args.first
      if first && !all_commands.key?(first) &&
          (first == "-" || !first.start_with?("-"))
        given_args = ["lint", *given_args]
      end
      super
    end

    # The test entry point. It keeps the old module interface.
    def self.run(argv)
      start(argv)
    end

    default_task :lint
    desc "lint FILE_OR_DIR...", "Lint Markdown prose and code comments (- reads stdin)"
    method_option :format, type: :string, default: "text", enum: %w[text json sarif],
      banner: "text|json|sarif"
    def lint(*paths)
      if paths.empty?
        help("lint")
        return 2
      end
      config =
        begin
          SimpleEnglish::Config.load
        rescue SimpleEnglish::Config::ConfigError => e
          warn "error: #{e.message}"
          return 2
        end
      results = []
      self.class.expand_paths(paths).each do |path|
        next if path != "-" && SimpleEnglish::Config.ignore?(config, path)
        unless path == "-" || File.readable?(path)
          warn "error: file not readable: #{path}"
          return 2
        end
        text = (path == "-") ? $stdin.read : File.read(path)
        findings = SimpleEnglish.lint_file(path, text)
        return 2 if findings.nil? # already warned why
        SimpleEnglish::Config.filter(config, path, findings).each do |finding|
          results << [path, finding]
        end
      end
      self.class.report(results, options[:format])
      results.empty? ? 0 : 1
    end

    desc "version", "Print the gem version. The container image tag is v plus this."
    def version
      puts SimpleEnglish::VERSION
      0
    end

    desc "serve", "Run the lint daemon in the foreground"
    method_option :port, type: :numeric, default: SimpleEnglish::Client::DEFAULT_PORT,
      desc: "Port to listen on"
    method_option :"dev-log", type: :string, banner: "PATH",
      desc: "Write daemon stderr to PATH"
    method_option :detached, type: :boolean,
      desc: "Replace any running se daemon and run in the background"
    def serve
      if options[:detached]
        daemon = SimpleEnglish::Server.start_detached(port: options[:port],
          install: SimpleEnglish::Install.from_env, dev_log: options[:"dev-log"])
        if daemon
          puts "se daemon detached, pid #{daemon["pid"]}, " \
            "on http://localhost:#{options[:port]}"
          return 0
        end
        warn "error: detached daemon did not come up. " \
          "Run `se serve` and read its output."
        return 2
      end
      log = options[:"dev-log"] ? File.open(options[:"dev-log"], "w") : $stderr
      SimpleEnglish::Server.start(port: options[:port],
        install: SimpleEnglish::Install.from_env, log: log)
      0
    rescue SimpleEnglish::Install::SetupError, SimpleEnglish::Server::ServerError,
      SimpleEnglish::Config::ConfigError => e
      warn "error: #{e.message}"
      2
    end

    desc "setup", "Download LanguageTool and locate Java. Idempotent."
    method_option :dir, type: :string, banner: "PATH",
      desc: "Install into PATH (default: the shared cache)"
    def setup
      install = SimpleEnglish::Install.from_env
      lt_dir = SimpleEnglish::LanguageTool.install(options[:dir] || install.cache_dir)
      return 2 unless lt_dir
      unless install.java?
        warn "error: java not found. Install a JRE (on macOS: brew install openjdk), " \
          "or set SE_JAVA to your java binary."
        return 2
      end
      unless SimpleEnglish::LanguageTool.smoke(install)
        warn "error: LanguageTool smoke test failed. The download may be corrupt. " \
          "Delete #{lt_dir} and rerun `se setup`."
        return 2
      end
      puts <<~SETUP
        LanguageTool #{SimpleEnglish::LanguageTool::LT_VERSION} is at #{lt_dir}

        se finds it there automatically. Nothing to export.
      SETUP
      0
    end

    # "-" stays as-is for stdin. Directories expand to all lintable files.
    # Glob output keeps a "./" prefix when the argument is ".". Strip it so
    # paths and config ignore globs always see the same form.
    def self.expand_paths(argv)
      extensions = (SimpleEnglish::Extractor::EXTENSION_LANGUAGES.keys.map { |e| e.delete_prefix(".") } + ["md"]).uniq.join(",")
      argv.flat_map do |path|
        if File.directory?(path)
          Dir.glob(File.join(path, "**/*.{#{extensions}}")).sort
        else
          path
        end
      end.map { |path| path.delete_prefix("./") }
    end

    def self.report(results, format)
      require "json"
      case format
      when "json"
        puts JSON.pretty_generate(results.map do |path, finding|
          {"path" => path, "line" => finding.line, "column" => finding.column,
           "end_line" => finding.end_line, "end_column" => finding.end_column,
           "rule" => finding.rule, "message" => finding.message}
        end)
      when "sarif"
        puts JSON.pretty_generate(
          "version" => "2.1.0",
          "$schema" => "https://json.schemastore.org/sarif-2.1.0.json",
          "runs" => [{
            "columnKind" => "utf16CodeUnits",
            "tool" => {"driver" => {"name" => "se"}},
            "results" => results.map do |path, finding|
              region = {"startLine" => finding.line}
              if finding.column
                region["startColumn"] = finding.column
                if finding.end_line && finding.end_column
                  region["endLine"] = finding.end_line
                  region["endColumn"] = finding.end_column
                end
              end
              {"ruleId" => finding.rule, "level" => "error",
               "message" => {"text" => finding.message},
               "locations" => [{"physicalLocation" => {
                 "artifactLocation" => {"uri" => path},
                 "region" => region
               }}]}
            end
          }]
        )
      else
        results.each do |path, finding|
          location = "#{path}:#{finding.line}"
          if finding.column
            location += ":#{finding.column}"
            if finding.end_line && finding.end_column
              finish = (finding.end_line == finding.line) ? finding.end_column :
                "#{finding.end_line}:#{finding.end_column}"
              location += "-#{finish}"
            end
          end
          puts "#{location}: [#{finding.rule}] #{finding.message}"
        end
      end
    end
  end
end
