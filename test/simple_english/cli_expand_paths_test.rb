# frozen_string_literal: true

require_relative "test_helper"

class CLIExpandPathsTest < Minitest::Test
  def test_keeps_stdin_dash_and_files
    assert_equal ["-", "doc.md"], SimpleEnglish::CLI.expand_paths(["-", "doc.md"])
  end

  def test_strips_dot_slash_prefix_so_ignore_globs_match
    in_tmpdir(chdir: true) do |_dir|
      File.write("a.md", "x")
      assert_equal ["a.md"], SimpleEnglish::CLI.expand_paths(["."])
    end
  end

  def test_skips_vendored_and_git_directories_when_expanding
    in_tmpdir do |dir|
      File.write(File.join(dir, "a.md"), "x")
      [".git", "node_modules", "vendor"].each do |skipped|
        sub = File.join(dir, skipped)
        Dir.mkdir(sub)
        File.write(File.join(sub, "b.md"), "x")
      end

      expanded = SimpleEnglish::CLI.expand_paths([dir])
      assert_equal [File.join(dir, "a.md")], expanded
    end
  end

  def test_expands_directories_to_markdown_files_recursively
    in_tmpdir do |dir|
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
