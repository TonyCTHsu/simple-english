# frozen_string_literal: true

# MCP JSON-RPC responder for the lint engine. Pure: request Hash in,
# response Hash or nil (notifications) out. The stdio loop and the CLI
# wiring live elsewhere. Protocol facts: integrations/verification.md.

module SimpleEnglish
  module MCP
    SUPPORTED_VERSIONS = ["2025-06-18", "2025-03-26", "2024-11-05"].freeze
    LATEST_VERSION = "2025-06-18"
    SERVER_NAME = "simple-english"

    module_function

    def respond(request, linter:)
      return nil unless request.key?("id")
      id = request.fetch("id")
      method = request.fetch("method")
      case method
      when "initialize" then ok(id, initialize_result(request.dig("params", "protocolVersion")))
      when "tools/list" then ok(id, {"tools" => [lint_tool]})
      when "tools/call" then tools_call(id, request.fetch("params", {}), linter)
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
      tool = params.fetch("name", "")
      return error(id, -32602, "Unknown tool: #{tool}") unless tool == "lint"
      path = params.dig("arguments", "path")
      return ok(id, tool_error("the path argument is required.")) if path.nil? || path.to_s.empty?
      return ok(id, tool_error("#{path} is a directory. Give one file.")) if File.directory?(path)
      return ok(id, tool_error("file not found: #{path}")) unless File.exist?(path)
      findings = linter.call(path)
      if findings.nil?
        error(id, -32603, "the se daemon did not answer. Run `se serve --detached` and retry.")
      else
        ok(id, {"content" => [{"type" => "text", "text" => render(path, findings)}], "isError" => false})
      end
    end

    def render(path, findings)
      return "clean" if findings.empty?
      findings.map do |finding|
        location = "#{path}:#{finding.line}"
        if finding.column
          location += ":#{finding.column}"
          if finding.end_line && finding.end_column
            finish = (finding.end_line == finding.line) ? finding.end_column : "#{finding.end_line}:#{finding.end_column}"
            location += "-#{finish}"
          end
        end
        "#{location}: [#{finding.rule}] #{finding.message}"
      end.join("\n")
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
