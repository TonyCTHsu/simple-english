# frozen_string_literal: true

require_relative "test_helper"

class CLIExpandPathsTest < Minitest::Test
  def test_keeps_stdin_dash_and_files
    assert_equal ["-", "doc.md"], SimpleEnglish::CLI.expand_paths(["-", "doc.md"])
  end

  def test_strips_dot_slash_prefix_so_ignore_globs_match
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("a.md", "x")
        assert_equal ["a.md"], SimpleEnglish::CLI.expand_paths(["."])
      end
    end
  end

  def test_expands_directories_to_markdown_files_recursively
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "a.md"), "x")
      subdir = File.join(dir, "sub")
      Dir.mkdir(subdir)
      File.write(File.join(subdir, "b.md"), "x")
      File.write(File.join(dir, "c.txt"), "x")

      expanded = SimpleEnglish::CLI.expand_paths([dir])
      assert_equal [File.join(dir, "a.md"), File.join(subdir, "b.md")], expanded
    end
  end
end
