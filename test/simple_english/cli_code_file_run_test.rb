# frozen_string_literal: true

require_relative "test_helper"

class CLICodeFileRunTest < Minitest::Test
  def test_run_lints_code_files_through_the_daemon
    in_tmpdir do |dir|
      File.write(File.join(dir, "b.py"), "x = 1\n")
      server = StubHTTPServer.new("/lint" => "[]")
      status = nil
      with_env("SE_SERVER_URL" => server.url) do
        capture_io do
          status = SimpleEnglish::CLI.run([dir])
        end
      end
      assert_equal 0, status
    ensure
      server&.shutdown
    end
  end
end
