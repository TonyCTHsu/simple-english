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

    def run_script(input_lines, linter: nil)
      input = StringIO.new(input_lines.map { |line| JSON.generate(line) }.join("\n") + "\n")
      output = StringIO.new(+"")
      if linter
        ModelContextProtocol.run(io: input, out: output, linter: linter)
      else
        ModelContextProtocol.run(io: input, out: output)
      end
      output.string
    end

    def test_run_flushes_each_answer_without_eof
      # An MCP client keeps stdin open while it waits for the answer.
      # Ruby buffers a pipe until 4 KB or EOF, so an unflushed response
      # never arrives and the client drops the server as unresponsive.
      in_r, in_w = IO.pipe
      out_r, out_w = IO.pipe
      out_w.sync = false # the real $stdout is buffered when piped
      thread = Thread.new do
        ModelContextProtocol.run(io: in_r, out: out_w, linter: ->(_p) { [] })
      end
      request = {"jsonrpc" => "2.0", "id" => 1, "method" => "initialize",
                 "params" => {"protocolVersion" => "2025-06-18"}}
      in_w.write(JSON.generate(request) + "\n")
      ready = IO.select([out_r], nil, nil, 2)
      assert ready, "the initialize answer never flushed"
      response = JSON.parse(out_r.readline)
      assert_equal 1, response.fetch("id")
      in_w.close
      thread.join
      out_w.close
      out_r.close
    ensure
      [in_r, in_w].each(&:close)
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

    def existing_file(name = "a.md")
      dir = Dir.mktmpdir("mcp_stdio")
      path = File.join(dir, name)
      FileUtils.touch(path)
      path
    end

    def test_run_survives_a_raising_tool_call
      calls = 0
      linter = lambda do |_path|
        calls += 1
        raise Errno::EACCES, "denied" if calls == 1
        []
      end
      path = existing_file
      lines = [
        {"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call",
         "params" => {"name" => "lint", "arguments" => {"path" => path}}},
        {"jsonrpc" => "2.0", "id" => 2, "method" => "tools/call",
         "params" => {"name" => "lint", "arguments" => {"path" => path}}}
      ]
      out = run_script(lines, linter: linter)
      responses = out.split("\n").map { |line| JSON.parse(line) }
      assert_equal(-32603, responses[0].dig("error", "code"))
      assert_includes responses[0].dig("error", "message"), "EACCES"
      assert_equal "clean", responses[1].dig("result", "content").first.fetch("text")
    end

    def test_default_linter_honors_disabled_rules
      Dir.mktmpdir("mcp_config") do |dir|
        path = File.join(dir, "doc.md")
        FileUtils.touch(path)
        File.write(File.join(dir, ".simple-english.yml"), "disabled-rules:\n  - SE_X\n")
        findings = [Finding.new(1, nil, nil, nil, "SE_X", "gone"),
          Finding.new(2, nil, nil, nil, "SE_KEEP", "kept")]
        Dir.chdir(dir) do
          SimpleEnglish.stub(:lint_file, findings) do
            out = run_script(script_lines(path))
            text = JSON.parse(out.split("\n").last).dig("result", "content").first.fetch("text")
            assert_includes text, "SE_KEEP"
            refute_includes text, "SE_X"
          end
        end
      end
    end

    def test_default_linter_skips_ignored_paths
      Dir.mktmpdir("mcp_config") do |dir|
        path = File.join(dir, "doc.md")
        FileUtils.touch(path)
        File.write(File.join(dir, ".simple-english.yml"), "ignore:\n  - doc.md\n")
        Dir.chdir(dir) do
          SimpleEnglish.stub(:lint_file, ->(_p) { raise "must not lint an ignored path" }) do
            out = run_script(script_lines("doc.md"))
            assert_equal "clean", JSON.parse(out.split("\n").last).dig("result", "content").first.fetch("text")
          end
        end
      end
    end

    def test_bad_config_reports_an_error_not_a_crash
      Dir.mktmpdir("mcp_config") do |dir|
        path = File.join(dir, "doc.md")
        FileUtils.touch(path)
        File.write(File.join(dir, ".simple-english.yml"), ":!bad yaml: [\n")
        Dir.chdir(dir) do
          out = run_script(script_lines(path))
          response = JSON.parse(out.split("\n").last)
          assert response.dig("result", "isError")
          assert_includes response.dig("result", "content").first.fetch("text"), ".simple-english.yml"
        end
      end
    end

    def test_run_stays_silent_for_notifications
      input = StringIO.new(JSON.generate({"jsonrpc" => "2.0", "method" => "notifications/initialized"}) + "\n")
      output = StringIO.new(+"")
      ModelContextProtocol.run(io: input, out: output, linter: ->(_p) { [] })
      assert_equal "", output.string
    end

    def test_run_skips_blank_and_malformed_lines
      input = StringIO.new("\nnot json\n")
      output = StringIO.new("")
      ModelContextProtocol.run(io: input, out: output, linter: ->(_p) { [] })
      assert_equal "", output.string
    end

    def test_run_skips_json_that_is_not_an_object
      input = StringIO.new("\"just a string\"\n")
      output = StringIO.new("")
      ModelContextProtocol.run(io: input, out: output, linter: ->(_p) { [] })
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
