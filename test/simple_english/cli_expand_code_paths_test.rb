# frozen_string_literal: true

require_relative "test_helper"

class CLIExpandCodePathsTest < Minitest::Test
  def test_expands_directories_to_all_supported_extensions
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "a.md"), "x")
      File.write(File.join(dir, "b.py"), "x = 1\n")
      File.write(File.join(dir, "c.yaml"), "key: value\n")
      File.write(File.join(dir, "d.js"), "x = 1;\n")
      File.write(File.join(dir, "e.txt"), "x")

      expanded = SimpleEnglish::CLI.expand_paths([dir])
      assert_equal [File.join(dir, "a.md"), File.join(dir, "b.py"),
        File.join(dir, "c.yaml"), File.join(dir, "d.js")], expanded
    end
  end
end
