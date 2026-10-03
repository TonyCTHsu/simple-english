# frozen_string_literal: true

require_relative "test_helper"

class SetupCLITest < Minitest::Test
  def test_setup_reports_the_bundled_server_ready
    in_tmpdir do |dir|
      executable = File.join(dir, "server")
      File.write(executable, "#!/bin/sh\n")
      File.chmod(0o755, executable)
      with_env("SE_LANGUAGETOOL_EXECUTABLE" => executable) do
        out, err = capture_io do
          assert_equal 0, SimpleEnglish::CLI.run(["setup"])
        end
        assert_includes out, "simple_english is ready"
        assert_empty err
      end
    end
  end

  def test_setup_exits_2_when_the_bundled_server_is_missing
    with_env("SE_LANGUAGETOOL_EXECUTABLE" => "/nonexistent/server") do
      _out, err = capture_io do
        assert_equal 2, SimpleEnglish::CLI.run(["setup"])
      end
      assert_includes err, "lint engine not found"
    end
  end
end
