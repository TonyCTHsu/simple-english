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
    assert_includes error.message, SimpleEnglish::LanguageTool::EXECUTABLE_ENV
    assert_includes error.message, install.executable
  end

  def test_executable_bang_rejects_a_non_executable_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "server")
      File.write(path, "not executable")
      install = SimpleEnglish::Install.new(executable: path)
      refute install.executable?
      error = assert_raises(SimpleEnglish::Install::SetupError) do
        install.executable!
      end
      assert_includes error.message, SimpleEnglish::LanguageTool::EXECUTABLE_ENV
      assert_includes error.message, path
    end
  end

  def test_setup_error_reports_a_broken_platform_install
    Dir.mktmpdir do |dir|
      bundled = File.join(dir, "languagetool-server")
      swap_bundled_executable(bundled) do
        install = SimpleEnglish::Install.new(executable: bundled)
        error = assert_raises(SimpleEnglish::Install::SetupError) do
          install.executable!
        end
        assert_includes error.message, "reinstall the gem"
      end
    end
  end

  def test_setup_error_reports_no_engine_in_the_plain_gem
    Dir.mktmpdir do |dir|
      bundled = File.join(dir, "missing", "languagetool-server")
      swap_bundled_executable(bundled) do
        install = SimpleEnglish::Install.new(executable: bundled)
        error = assert_raises(SimpleEnglish::Install::SetupError) do
          install.executable!
        end
        assert_includes error.message, "plain gem"
        assert_includes error.message, SimpleEnglish::LanguageTool::EXECUTABLE_ENV
      end
    end
  end

  # The directory check in setup_error branches on whether the gem
  # shipped an engine at all, so the tests point the bundled path at
  # temporary directories instead of the real libexec.
  def swap_bundled_executable(path)
    language_tool = SimpleEnglish::LanguageTool
    saved = language_tool.const_get(:BUNDLED_EXECUTABLE)
    language_tool.send(:remove_const, :BUNDLED_EXECUTABLE)
    language_tool.const_set(:BUNDLED_EXECUTABLE, path)
    yield
  ensure
    language_tool.send(:remove_const, :BUNDLED_EXECUTABLE)
    language_tool.const_set(:BUNDLED_EXECUTABLE, saved)
  end
end
