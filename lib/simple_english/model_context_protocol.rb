# frozen_string_literal: true

require "json"

# MCP JSON-RPC server for the lint engine. `respond` is pure: request
# Hash in, response Hash or nil (notifications) out. `run` drives it
# over stdio, one JSON-RPC message per line. Protocol facts:
# integrations/verification.md.

module SimpleEnglish
  module ModelContextProtocol
    SUPPORTED_VERSIONS = ["2025-06-18", "2025-03-26", "2024-11-05"].freeze
    LATEST_VERSION = "2025-06-18"
    SERVER_NAME = "simple-english"

    module_function

    def run(io: $stdin, out: $stdout, linter: method(:default_linter))
      while (line = io.gets)
        line = line.strip
        next if line.empty?
        begin
          request = JSON.parse(line)
        rescue JSON::ParserError
          next
        end
        next unless request.is_a?(Hash)
        response =
          begin
            respond(request, linter: linter)
          rescue => e
            # A broken tool call (unreadable file, daemon hiccup) must not
            # kill the loop: answer it, then serve the next line.
            request.key?("id") ? error(request["id"], -32603, "lint failed: #{e.class}: #{e.message}") : nil
          end
        out.puts JSON.generate(response) if response
      end
    end

    # The CLI's lint pipeline as a callable: .simple-english.yml decides
    # which paths and rules count, then the daemon lints the file.
    def default_linter(path)
      config = SimpleEnglish::Config.load
      return [] if SimpleEnglish::Config.ignore?(config, path)
      findings = SimpleEnglish.lint_file(path)
      findings.nil? ? nil : SimpleEnglish::Config.filter(config, path, findings)
    end

    def respond(request, linter:)
      return nil unless request.key?("id")
      id = request.fetch("id")
      method = request["method"]
      return error(id, -32600, "Invalid Request") unless method.is_a?(String)
      params = request["params"]
      params = {} unless params.is_a?(Hash)
      case method
      when "initialize" then ok(id, initialize_result(params["protocolVersion"]))
      when "tools/list" then ok(id, {"tools" => [lint_tool]})
      when "tools/call" then tools_call(id, params, linter)
      else error(id, -32601, "Method not found: #{method}")
      end
    end

    def initialize_result(requested_version)
      version = SUPPORTED_VERSIONS.include?(requested_version) ? requested_version : LATEST_VERSION
      {
        "protocolVersion" => version,
        "capabilities" => {"tools" => {}},
        "serverInfo" => {"name" => SERVER_NAME, "version" => SimpleEnglish::VERSION}
      }
    end

    def lint_tool
      {
        "name" => "lint",
        "description" =>
          "Lint Markdown prose and code comments against plain-English rules " \
          "(short sentences, active voice, no jargon, no filler). " \
          "Input: a file path. Returns one line per finding, or 'clean' when " \
          "nothing is flagged. Fix the findings, then call again until clean.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {"path" => {"type" => "string", "description" => "File to lint"}},
          "required" => ["path"]
        }
      }
    end

    def tools_call(id, params, linter)
      tool = params["name"]
      return error(id, -32602, "Unknown tool: #{tool}") unless tool == "lint"
      arguments = params["arguments"]
      arguments = {} unless arguments.is_a?(Hash)
      path = arguments["path"]
      return ok(id, tool_error("the path argument is required.")) if path.nil? || path.to_s.empty?
      return ok(id, tool_error("#{path} is a directory. Give one file.")) if File.directory?(path)
      return ok(id, tool_error("file not found: #{path}")) unless File.exist?(path)
      findings =
        begin
          linter.call(path)
        rescue SimpleEnglish::Config::ConfigError => e
          return ok(id, tool_error("invalid .simple-english.yml: #{e.message}"))
        end
      if findings.nil?
        error(id, -32603, "the se daemon did not answer. Run `se serve --detached` and retry.")
      else
        ok(id, {"content" => [{"type" => "text", "text" => render(path, findings)}], "isError" => false})
      end
    end

    def render(path, findings)
      return "clean" if findings.empty?
      findings.map { |finding| finding.to_line(path) }.join("\n")
    end

    def tool_error(text)
      {"content" => [{"type" => "text", "text" => text}], "isError" => true}
    end

    def ok(id, result)
      {"jsonrpc" => "2.0", "id" => id, "result" => result}
    end

    def error(id, code, message)
      {"jsonrpc" => "2.0", "id" => id, "error" => {"code" => code, "message" => message}}
    end
  end
end
