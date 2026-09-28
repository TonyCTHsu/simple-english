# frozen_string_literal: true

require_relative "test_helper"

class CLICodeFileRunTest < Minitest::Test
  def test_run_lints_code_files_through_the_daemon
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "b.py"), "x = 1\n")
      server = StubHTTPServer.new("/lint" => "[]")
      previous = ENV["SE_SERVER_URL"]
      ENV["SE_SERVER_URL"] = server.url
      status = nil
      capture_io do
        status = SimpleEnglish::CLI.run([dir])
      end
      assert_equal 0, status
    ensure
      ENV["SE_SERVER_URL"] = previous
      server&.shutdown
    end
  end
end
