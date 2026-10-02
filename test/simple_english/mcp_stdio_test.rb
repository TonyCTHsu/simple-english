# frozen_string_literal: true

require_relative "test_helper"

module SimpleEnglish
  class MCPStdioTest < Minitest::Test
    def script_lines(path)
      [
        {"jsonrpc" => "2.0", "id" => 1, "method" => "initialize",
         "params" => {"protocolVersion" => "2025-06-18", "capabilities" => {},
                      "clientInfo" => {"name" => "t", "version" => "0"}}},
        {"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list", "params" => {}},
        {"jsonrpc" => "2.0", "id" => 3, "method" => "tools/call",
         "params" => {"name" => "lint", "arguments" => {"path" => path}}}
      ]
    end

    def run_script(input_lines, linter:)
      input = StringIO.new(input_lines.map { |line| JSON.generate(line) }.join("\n") + "\n")
      output = StringIO.new(+"")
      Daemon::MCP.run(io: input, out: output, linter: linter)
      output.string
    end

    def test_run_answers_each_request_in_order
      dir = Dir.mktmpdir("mcp_stdio")
      path = File.join(dir, "a.md")
      FileUtils.touch(path)
      out = run_script(script_lines(path), linter: ->(_p) { [] })
      responses = out.split("\n").map { |line| JSON.parse(line) }
      assert_equal [1, 2, 3], responses.map { |r| r.fetch("id") }
      assert_equal "simple-english", responses[0].dig("result", "serverInfo", "name")
      assert_equal "lint", responses[1].dig("result", "tools").first.fetch("name")
      assert_equal "clean", responses[2].dig("result", "content").first.fetch("text")
    end

    def test_run_stays_silent_for_notifications
      input = StringIO.new(JSON.generate({"jsonrpc" => "2.0", "method" => "notifications/initialized"}) + "\n")
      output = StringIO.new(+"")
      Daemon::MCP.run(io: input, out: output, linter: ->(_p) { [] })
      assert_equal "", output.string
    end

    def test_run_skips_blank_and_malformed_lines
      input = StringIO.new("\nnot json\n")
      output = StringIO.new("")
      Daemon::MCP.run(io: input, out: output, linter: ->(_p) { [] })
      assert_equal "", output.string
    end

    def test_run_skips_json_that_is_not_an_object
      input = StringIO.new("\"just a string\"\n")
      output = StringIO.new("")
      Daemon::MCP.run(io: input, out: output, linter: ->(_p) { [] })
      assert_equal "", output.string
    end

    def test_run_ends_cleanly_at_eof
      out = run_script([], linter: ->(_p) { [] })
      assert_equal "", out
    end

    def test_run_writes_compact_json_one_per_line
      dir = Dir.mktmpdir("mcp_stdio")
      path = File.join(dir, "a.md")
      FileUtils.touch(path)
      out = run_script([script_lines(path).first], linter: ->(_p) { [] })
      assert_equal 1, out.lines.length
      refute_includes out, "\n\n"
    end
  end
end
