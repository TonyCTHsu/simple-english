# frozen_string_literal: true

require_relative "test_helper"

module SimpleEnglish
  class MCPRespondTest < Minitest::Test
    def request(id, method, params = {})
      {"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
    end

    def linter_returning(findings)
      ->(_path) { findings }
    end

    def existing_file(name)
      dir = Dir.mktmpdir("mcp_respond")
      path = File.join(dir, name)
      FileUtils.touch(path)
      path
    end

    def test_initialize_echoes_supported_protocol_version
      response = MCP.respond(
        request(1, "initialize", {"protocolVersion" => "2025-06-18"}),
        linter: linter_returning([])
      )
      result = response.fetch("result")
      assert_equal "2025-06-18", result.fetch("protocolVersion")
      assert_equal "simple-english", result.dig("serverInfo", "name")
      assert_equal SimpleEnglish::VERSION, result.dig("serverInfo", "version")
    end

    def test_initialize_answers_latest_version_for_unsupported_request
      response = MCP.respond(
        request(1, "initialize", {"protocolVersion" => "1999-01-01"}),
        linter: linter_returning([])
      )
      assert_equal "2025-06-18", response.dig("result", "protocolVersion")
    end

    def test_tools_list_returns_the_lint_tool
      response = MCP.respond(request(2, "tools/list"), linter: linter_returning([]))
      tools = response.dig("result", "tools")
      assert_equal 1, tools.length
      tool = tools.first
      assert_equal "lint", tool.fetch("name")
      assert_equal ["path"], tool.dig("inputSchema", "required")
      assert_equal "string", tool.dig("inputSchema", "properties", "path", "type")
    end

    def test_tools_call_renders_one_line_per_finding
      findings = [
        Finding.new(1, 12, 1, 26, "SE_ACTIVE_VOICE", "Use the active voice."),
        Finding.new(3, nil, nil, nil, "SE_COUNT_WORDS", "Too many words.")
      ]
      path = existing_file("a.md")
      response = MCP.respond(
        request(3, "tools/call", {"name" => "lint", "arguments" => {"path" => path}}),
        linter: ->(_path) { findings }
      )
      result = response.fetch("result")
      refute result.fetch("isError")
      text = result.fetch("content").first.fetch("text")
      assert_equal 2, text.lines.length
      assert_includes text, "#{path}:1:12-26: [SE_ACTIVE_VOICE] Use the active voice."
      assert_includes text, "#{path}:3: [SE_COUNT_WORDS] Too many words."
    end

    def test_tools_call_answers_clean_when_no_findings
      path = existing_file("a.md")
      response = MCP.respond(
        request(4, "tools/call", {"name" => "lint", "arguments" => {"path" => path}}),
        linter: linter_returning([])
      )
      result = response.fetch("result")
      refute result.fetch("isError")
      assert_equal "clean", result.fetch("content").first.fetch("text")
    end

    def test_tools_call_reports_unreachable_daemon_as_json_rpc_error
      path = existing_file("a.md")
      response = MCP.respond(
        request(5, "tools/call", {"name" => "lint", "arguments" => {"path" => path}}),
        linter: ->(_path) {}
      )
      assert_equal 5, response.fetch("id")
      assert_equal(-32603, response.dig("error", "code"))
      assert_includes response.dig("error", "message"), "daemon"
    end

    def test_tools_call_rejects_a_missing_path
      response = MCP.respond(
        request(6, "tools/call", {"name" => "lint", "arguments" => {}}),
        linter: linter_returning([])
      )
      result = response.fetch("result")
      assert result.fetch("isError")
      assert_includes result.fetch("content").first.fetch("text"), "path"
    end

    def test_tools_call_rejects_a_directory
      response = MCP.respond(
        request(7, "tools/call", {"name" => "lint", "arguments" => {"path" => __dir__}}),
        linter: linter_returning([])
      )
      result = response.fetch("result")
      assert result.fetch("isError")
      assert_includes result.fetch("content").first.fetch("text"), "directory"
    end

    def test_tools_call_rejects_a_file_that_does_not_exist
      response = MCP.respond(
        request(8, "tools/call", {"name" => "lint", "arguments" => {"path" => "no/such/file.md"}}),
        linter: linter_returning([])
      )
      result = response.fetch("result")
      assert result.fetch("isError")
      assert_includes result.fetch("content").first.fetch("text"), "no/such/file.md"
    end

    def test_tools_call_rejects_an_unknown_tool
      response = MCP.respond(
        request(9, "tools/call", {"name" => "nope", "arguments" => {}}),
        linter: linter_returning([])
      )
      assert_equal(-32602, response.dig("error", "code"))
      assert_includes response.dig("error", "message"), "nope"
    end

    def test_unknown_method_answers_method_not_found
      response = MCP.respond(request(10, "no/such/method"), linter: linter_returning([]))
      assert_equal(-32601, response.dig("error", "code"))
      assert_equal 10, response.fetch("id")
    end

    def test_notification_without_id_returns_nil
      notification = {"jsonrpc" => "2.0", "method" => "notifications/initialized"}
      assert_nil MCP.respond(notification, linter: linter_returning([]))
    end
  end
end
