# frozen_string: true

require_relative "test_helper"

require "fileutils"

# `se setup` must only report success when lint will actually work:
# java found and the downloaded LanguageTool passes a smoke run.
# Both failure paths are simulated with a fake cache and a java that
# cannot run, so no real LanguageTool is needed here.
class SetupCLITest < Minitest::Test
  def test_setup_exits_2_and_names_the_fix_when_java_is_missing
    in_fake_cache do |env|
      # PATH without java and no Homebrew java (stubbed away), so
      # Install.from_env resolves no java at all. SE_JAVA is unset
      # so a real one on the host cannot leak in.
      stub_file_executable?(false) do
        with_env(env.merge("PATH" => "/nonexistent", "SE_JAVA" => nil)) do
          _, err = capture_io do
            assert_equal 2, SimpleEnglish::CLI.run(["setup"])
          end
          assert_match(/java not found/, err)
          assert_match(/SE_JAVA/, err)
        end
      end
    end
  end

  def test_setup_exits_2_when_the_smoke_test_fails
    in_fake_cache do |env|
      # SE_JAVA is trusted outright, so java is "found" but cannot
      # run: the smoke test must fail setup.
      with_env(env.merge("SE_JAVA" => "/nonexistent/java")) do
        _, err = capture_io do
          assert_equal 2, SimpleEnglish::CLI.run(["setup"])
        end
        assert_match(/smoke test failed/, err)
      end
    end
  end

  private

  # A cache whose LanguageTool-<version> dir holds a commandline jar,
  # so LanguageTool.install's idempotent path skips the download.
  def in_fake_cache
    in_tmpdir do |cache|
      dir = File.join(cache, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "languagetool-commandline.jar"), "fake jar")
      yield({"SE_CACHE_DIR" => cache})
    end
  end

  # Same filesystem stub as install_test: hide the Homebrew java so
  # the no-java case is deterministic on machines that have openjdk.
  def stub_file_executable?(executable)
    real = File.method(:executable?)
    File.singleton_class.send(:define_method, :executable?) { |_| executable }
    yield
  ensure
    File.singleton_class.send(:define_method, :executable?) { |path| real.call(path) }
  end
end
