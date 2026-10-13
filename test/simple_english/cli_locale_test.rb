# frozen_string_literal: true

require_relative "test_helper"

require "json"

class CLILocaleTest < Minitest::Test
  FINDINGS = [
    {"line" => 1, "column" => 46, "end_line" => 1, "end_column" => 47,
     "rule" => "SE_NO_EMDASH",
     "message" => "Write two sentences, or use a comma."}
  ].to_json

  # The child runs with no LANG, like a GUI app (Claude Desktop) or a
  # cron job spawns it. Its Ruby then reads stdin as US-ASCII.
  def with_stdin_file(text)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "stdin")
      File.binwrite(path, text)
      yield path
    end
  end

  def test_stdin_lint_with_non_ascii_under_a_locale_less_process
    with_stdin_file("# Dogfooding — one-pager\n\nThe team ships a tracer.\n") do |stdin|
      Dir.mktmpdir do |dir|
        out_path = File.join(dir, "out")
        server = StubHTTPServer.new("/lint" => FINDINGS)
        env = {"PATH" => ENV["PATH"], "HOME" => ENV["HOME"],
               "LANG" => nil, "LC_ALL" => nil, "LC_CTYPE" => nil,
               "SE_SERVER_URL" => server.url}
        root = File.expand_path("../..", __dir__)
        pid = Process.spawn(env, RbConfig.ruby, File.join(root, "bin/se"), "lint", "-",
          in: stdin, out: out_path, err: [:child, :out], chdir: root)
        _, _ = Process.wait2(pid)
        output = File.read(out_path)
        # Findings make `lint` exit 1. A crash also exits 1, so the
        # finding line in the output is the proof of a real lint.
        assert_includes output, "SE_NO_EMDASH"
        refute_includes output, "invalid byte sequence"
      ensure
        server&.shutdown
      end
    end
  end

  def test_mcp_answers_a_request_line_with_non_ascii
    with_stdin_file('{"jsonrpc":"2.0","id":1,"method":"tools/call","params":' \
      '{"name":"lint","arguments":{"path":"/tmp/café.md"}}}' + "\n") do |stdin|
      Dir.mktmpdir do |dir|
        out_path = File.join(dir, "out")
        env = {"PATH" => ENV["PATH"], "HOME" => ENV["HOME"],
               "LANG" => nil, "LC_ALL" => nil, "LC_CTYPE" => nil}
        root = File.expand_path("../..", __dir__)
        pid = Process.spawn(env, RbConfig.ruby, File.join(root, "bin/se"), "mcp",
          in: stdin, out: out_path, err: IO::NULL, chdir: root)
        _, status = Process.wait2(pid)
        assert_equal 0, status.exitstatus, "the MCP server died before answering"
        response = JSON.parse(File.read(out_path))
        assert_equal 1, response.fetch("id")
        assert_match(/file not found/, response.dig("result", "content", 0, "text"))
      end
    end
  end
end
