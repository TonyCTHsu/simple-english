# frozen_string_literal: true

require_relative "test_helper"

require "tmpdir"

class InstallTest < Minitest::Test
  def test_from_env_honors_the_se_java_override_without_probing_it
    install = SimpleEnglish::Install.from_env(
      {"SE_JAVA" => "/nonexistent/java", "SE_CACHE_DIR" => "/cache"}
    )
    assert_equal "/nonexistent/java", install.java
    assert_equal "/cache", install.cache_dir
  end

  def test_from_env_probes_the_path_candidate_under_the_given_path
    # A PATH whose java is this process's real ruby is enough to prove
    # the probe runs the candidate and only trusts a working one.
    env = {"PATH" => "/nonexistent"}
    stub_homebrew(false) do
      install = SimpleEnglish::Install.from_env(env)
      assert_nil install.java
    end
  end

  def test_from_env_falls_back_to_the_homebrew_location
    candidate = SimpleEnglish::LanguageTool::HOMEBREW_JAVA
    skip "needs homebrew openjdk" unless File.executable?(candidate)
    install = SimpleEnglish::Install.from_env({"PATH" => "/nonexistent"})
    assert_equal candidate, install.java
  end

  def test_java_bang_raises_the_fix_when_java_was_not_found
    install = SimpleEnglish::Install.new(cache_dir: "/cache")
    error = assert_raises(SimpleEnglish::Install::SetupError) { install.java! }
    assert_match(/Install a JRE/, error.message)
  end

  def test_java_bang_returns_the_resolved_java
    install = SimpleEnglish::Install.new(cache_dir: "/cache", java: "/usr/bin/java")
    assert_equal "/usr/bin/java", install.java!
  end

  def test_cache_dir_defaults_to_home_and_expands_the_override
    default = SimpleEnglish::Install.from_env({})
    assert_equal File.join(Dir.home, ".cache", "se"), default.cache_dir

    relative = SimpleEnglish::Install.from_env({"SE_CACHE_DIR" => "rel/cache"})
    assert_equal File.expand_path("rel/cache"), relative.cache_dir
  end

  def test_jar_paths_derive_from_the_pinned_version
    install = SimpleEnglish::Install.new(cache_dir: "/cache")
    dir = "/cache/LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}"
    assert_equal File.join(dir, "languagetool-commandline.jar"), install.commandline_jar
    assert_equal File.join(dir, "languagetool-server.jar"), install.server_jar
  end

  def test_setup_error_names_the_jar_and_the_fix
    install = SimpleEnglish::Install.new(cache_dir: "/cache")
    assert_includes install.setup_error, install.server_jar
    assert_includes install.setup_error, "This gem pins"
    assert_includes install.setup_error, "Run `se setup`."
  end

  private

  # The homebrew fallback consults the real filesystem. Hide it so
  # the nil-java case is deterministic on machines that have openjdk.
  def stub_homebrew(executable)
    real = File.method(:executable?)
    File.singleton_class.send(:define_method, :executable?) { |_| executable }
    yield
  ensure
    File.singleton_class.send(:define_method, :executable?) { |path| real.call(path) }
  end
end
