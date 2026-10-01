# frozen_string_literal: true

require_relative "test_helper"

class CLIDispatchTest < Minitest::Test
  def test_bare_file_routed_to_lint
    _, err = capture_io do
      assert_equal 2, SimpleEnglish::CLI.run(["does-not-exist.md"])
    end
    assert_match(/file not readable: does-not-exist\.md/, err)
  end

  def test_stdin_dash_routed_to_lint
    server = StubHTTPServer.new("/lint" => "[]")
    status = nil
    with_env("SE_SERVER_URL" => server.url) do
      with_stdin("") do
        capture_io { status = SimpleEnglish::CLI.run(["-"]) }
      end
    end
    assert_equal 0, status
  ensure
    server&.shutdown
  end

  def test_version_prints_the_gem_version
    out, = capture_io { assert_equal 0, SimpleEnglish::CLI.run(["version"]) }
    assert_equal SimpleEnglish::VERSION, out.strip
  end

  def test_empty_invocation_prints_usage_and_returns_2
    out, = capture_io { assert_equal 2, SimpleEnglish::CLI.run([]) }
    assert_match(/lint/, out)
  end
end

class CLIServeTest < Minitest::Test
  def test_serve_detached_prints_the_handshake_and_exits_0
    SimpleEnglish::Server.stub :start_detached, ->(*) { {"pid" => 4242} } do
      out, = capture_io do
        assert_equal 0,
          SimpleEnglish::CLI.run(["serve", "--detached", "--port", "28291"])
      end
      assert_match(/pid 4242/, out)
      assert_match(/28291/, out)
    end
  end

  def test_serve_detached_failure_points_at_the_visible_serve
    SimpleEnglish::Server.stub :start_detached, ->(*) {} do
      _out, err = capture_io do
        assert_equal 2,
          SimpleEnglish::CLI.run(["serve", "--detached", "--port", "28291"])
      end
      assert_match(/Run `se serve` and read its output/, err)
    end
  end
end
