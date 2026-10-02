# frozen_string_literal: true

require_relative "test_helper"

require "tmpdir"

class InstallTest < Minitest::Test
  def test_from_env_uses_the_bundled_executable_by_default
    install = SimpleEnglish::Install.from_env({})
    assert_equal SimpleEnglish::LanguageTool::BUNDLED_EXECUTABLE,
      install.executable
  end

  def test_from_env_expands_the_executable_override
    install = SimpleEnglish::Install.from_env(
      {"SE_LANGUAGETOOL_EXECUTABLE" => "relative/server"}
    )
    assert_equal File.expand_path("relative/server"), install.executable
  end

  def test_executable_bang_returns_an_executable_file
    Dir.mktmpdir do |dir|
      executable = File.join(dir, "server")
      File.write(executable, "#!/bin/sh\n")
      File.chmod(0o755, executable)
      install = SimpleEnglish::Install.new(executable: executable)
      assert install.executable?
      assert_equal executable, install.executable!
    end
  end

  def test_executable_bang_rejects_a_missing_file
    install = SimpleEnglish::Install.new(executable: "/nonexistent/server")
    error = assert_raises(SimpleEnglish::Install::SetupError) do
      install.executable!
    end
    assert_includes error.message, install.executable
    assert_includes error.message, "supported platform build"
  end

  def test_executable_bang_rejects_a_non_executable_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "server")
      File.write(path, "not executable")
      install = SimpleEnglish::Install.new(executable: path)
      refute install.executable?
      assert_raises(SimpleEnglish::Install::SetupError) do
        install.executable!
      end
    end
  end
end
