# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "json"
require "tmpdir"

class ClientEnsureUpTest < Minitest::Test
  def test_lint_text_returns_nil_when_custom_url_is_dead
    with_env("SE_SERVER_URL" => "http://localhost:1") do
      _out, err = capture_io do
        assert_nil SimpleEnglish.lint_text("Fine text.\n")
      end
      assert_match(/SE_SERVER_URL is set but/, err)
    end
  end

  def test_ensure_up_fails_fast_with_setup_message_when_jar_is_missing
    in_tmpdir do |dir|
      # java is present so the jar is the named blocker, and the
      # jar matters only when the daemon is down and we must spawn it.
      install = SimpleEnglish::Install.new(cache_dir: dir, java: RbConfig.ruby)
      SimpleEnglish::Client.stub :info, nil do
        _out, err = capture_io do
          refute SimpleEnglish::Client.ensure_up(install: install)
        end
        assert_match(/Run `se setup`\./, err)
      end
    end
  end

  def test_ensure_up_fails_fast_naming_java_when_java_is_missing
    # Jar cached but java gone: fail fast instead of spawning a
    # doomed child and waiting out the full 90 s.
    in_tmpdir do |dir|
      lt = File.join(dir, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
      FileUtils.mkdir_p(lt)
      FileUtils.touch(File.join(lt, "languagetool-server.jar"))
      install = SimpleEnglish::Install.new(cache_dir: dir)
      with_se_server_url(nil) do
        SimpleEnglish::Client.stub :info, nil do
          SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "no spawn expected" } do
            _out, err = capture_io do
              refute SimpleEnglish::Client.ensure_up(install: install)
            end
            assert_match(/java not found/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_lints_against_a_daemon_without_a_handshake
    # A pre-handshake daemon answers but not with the handshake: lint
    # against it, no spawn - but say so, a stale lint must not be
    # silent.
    SimpleEnglish::Client.stub :info, :foreign do
      SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "no spawn expected" } do
        _out, err = capture_io do
          assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
        end
        assert_match(/not a handshake-capable se daemon/, err)
      end
    end
  end

  def test_ensure_up_warns_about_an_image_for_a_foreign_legacy_daemon
    # A pre-handshake daemon behind SE_SERVER_URL (a container image):
    # the fix is updating the image, not a local `se serve`.
    with_se_server_url("http://localhost:1") do
      SimpleEnglish::Client.stub :info, :foreign do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "no spawn expected" } do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_match(/pull a newer image or rebuild/, err)
        end
      end
    end
  end

  def test_ensure_up_warns_about_an_outdated_daemon
    # The daemon runs older code. A lint never replaces a running
    # daemon: `se serve` owns that. Warn, name the fix, lint against
    # it meanwhile.
    stale = {"version" => "0.1.0", "pid" => Process.pid,
             "gem_digest" => "old", "rules_digest" => "rules"}
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :info, stale do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "lints never replace a daemon" } do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_match(/runs se 0\.1\.0, different code than this install/, err)
          assert_match(/Run `se serve` to restart it/, err)
          assert_match(/Linting against it meanwhile/, err)
        end
      end
    end
  end

  def test_ensure_up_never_downgrades_a_newer_daemon
    # A newer daemon behind the default port belongs to a project
    # that bundles a newer gem. `se serve` from this install boots
    # an older daemon in its place, so the fix is updating this gem:
    # warn, lint, and leave it alone.
    newer = {"version" => "9.9.9", "pid" => 4242,
             "gem_digest" => "other", "rules_digest" => "rules"}
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :info, newer do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "must not spawn" } do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_match(/newer than this install/, err)
          assert_match(/Update this gem/, err)
        end
      end
    end
  end

  def test_ensure_up_warns_about_a_same_version_daemon_with_different_code
    # A dev checkout beside the installed gem: same version, different
    # code. The version cannot pick a winner, and the digest says the
    # running code is not this code. Lints never replace a daemon:
    # warn and lint against it.
    twin = {"version" => SimpleEnglish::VERSION, "pid" => Process.pid,
            "gem_digest" => "other", "rules_digest" => "rules"}
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :info, twin do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "lints never replace a daemon" } do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_match(/different code than this install/, err)
          assert_match(/Run `se serve` to restart it/, err)
        end
      end
    end
  end

  def test_boot_skips_the_spawn_when_a_concurrent_boot_already_started_it
    # Two lints find a cold port at once. The spawn lock serializes
    # them: the loser re-checks on wake, finds the winner's daemon
    # up, and never spawns a second child.
    winner = {"version" => SimpleEnglish::VERSION, "pid" => Process.pid,
              "gem_digest" => SimpleEnglish::Fingerprint.gem,
              "rules_digest" => "rules"}
    answers = [nil, winner]
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :info, -> { answers.shift } do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "the winner's daemon is up" } do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_empty err
        end
      end
    end
  end

  def test_boot_warns_when_the_winner_runs_different_code
    # The winner's `se serve` child comes from its own checkout: the
    # loser's post-lock recheck classifies the handshake like the
    # first probe, so the code mismatch is said out loud.
    winner = {"version" => SimpleEnglish::VERSION, "pid" => Process.pid,
              "gem_digest" => "winner's build", "rules_digest" => "rules"}
    answers = [nil, winner]
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :info, -> { answers.shift } do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "the winner's daemon is up" } do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_match(/different code than this install/, err)
          assert_match(/Run `se serve` to restart it/, err)
        end
      end
    end
  end

  def test_boot_reports_failure_when_the_spawned_daemon_never_answers
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :info, nil do
        SimpleEnglish::Client.stub :spawn_daemon, -> {} do
          SimpleEnglish::Client.stub :wait_for, false do
            _out, err = capture_io do
              refute SimpleEnglish::Client.ensure_up(install: install_with_jar)
            end
            assert_match(/did not come up/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_never_spawns_against_a_daemon_behind_se_server_url
    stale = {"version" => "0.1.0", "pid" => 4242,
             "gem_digest" => "old", "rules_digest" => "rules"}
    with_se_server_url("http://localhost:1") do
      SimpleEnglish::Client.stub :info, stale do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "must not spawn" } do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_match(/not restarted automatically/, err)
        end
      end
    end
  end

  def test_ensure_up_is_quiet_when_everything_matches
    daemon = {"version" => SimpleEnglish::VERSION, "pid" => 4242,
              "gem_digest" => SimpleEnglish::Fingerprint.gem,
              "rules_digest" => "rules"}
    SimpleEnglish::Client.stub :info, daemon do
      _out, err = capture_io do
        assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
      end
      assert_empty err
    end
  end

  def test_the_spawn_lock_is_keyed_by_port_not_the_cache_dir
    # Daemon ownership is scoped to the port, not the cache: two
    # lints with different SE_CACHE_DIR values still take the same
    # lock, because it lives under HOME, keyed by the port.
    home = Dir.mktmpdir
    (@tmpdirs ||= []) << home
    with_env("HOME" => home) do
      with_se_server_url(nil) do
        SimpleEnglish::Client.stub :info, nil do
          SimpleEnglish::Client.stub :spawn_daemon, -> {} do
            SimpleEnglish::Client.stub :wait_for, false do
              _out, _err = capture_io do
                refute SimpleEnglish::Client.ensure_up(install: install_with_jar)
              end
            end
          end
        end
      end
    end
    assert File.exist?(File.join(home, ".cache", "simple_english", "spawn-8181.lock"))
    refute File.exist?(File.join(install_with_jar.cache_dir, "spawn.lock"))
  end

  private

  def with_se_server_url(value)
    old = ENV["SE_SERVER_URL"]
    value ? ENV["SE_SERVER_URL"] = value : ENV.delete("SE_SERVER_URL")
    yield
  ensure
    if old
      ENV["SE_SERVER_URL"] = old
    else
      ENV.delete("SE_SERVER_URL")
    end
  end

  def install_with_jar
    dir = Dir.mktmpdir
    (@tmpdirs ||= []) << dir
    lt = File.join(dir, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
    FileUtils.mkdir_p(lt)
    FileUtils.touch(File.join(lt, "languagetool-server.jar"))
    # Any real binary stands in for java: the boot path only
    # checks that one exists, and the spawn is stubbed in these tests.
    SimpleEnglish::Install.new(cache_dir: dir, java: RbConfig.ruby)
  end

  def teardown
    Array(@tmpdirs).each { |dir| FileUtils.remove_entry(dir) }
  end
end
