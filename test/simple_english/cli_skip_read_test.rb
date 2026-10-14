# frozen_string_literal: true

require_relative "test_helper"

class CLISkipReadTest < Minitest::Test
  # The readable check above is a stat. The read belongs behind the
  # lintable gate in Linter, so a non-lintable file costs no read.
  def test_cli_does_not_read_non_lintable_files
    in_tmpdir(chdir: true) do |_dir|
      File.write("blob.bin", "x")
      File.stub(:read, ->(*) { flunk "the CLI must not read a non-lintable file" }) do
        assert_equal 0, SimpleEnglish::CLI.run(["lint", "blob.bin"])
      end
    end
  end
end
