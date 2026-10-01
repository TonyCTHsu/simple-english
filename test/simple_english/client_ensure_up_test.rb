# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "json"
require "tmpdir"

class ClientEnsureUpTest < Minitest::Test
  def test_up_is_true_when_daemon_answers
    server = StubHTTPServer.new("/v2/check" => lambda { |_body| [200, {matches: []}.to_json] })
    assert_equal true, SimpleEnglish::Client.up?(base_url: server.url)
    server.shutdown
  end

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
      SimpleEnglish::Client.stub :up?, false do
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
        SimpleEnglish::Client.stub :up?, false do
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
    # A pre-handshake daemon answers HEAD but not GET /: lint against
    # it, no restart, no spawn - but say so, a stale lint must not be
    # silent.
    SimpleEnglish::Client.stub :up?, true do
      SimpleEnglish::Client.stub :info, nil do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "no spawn expected" } do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_match(/not a handshake-capable se daemon/, err)
        end
      end
    end
  end

  def test_ensure_up_warns_about_an_image_for_a_foreign_legacy_daemon
    # A pre-handshake daemon behind SE_SERVER_URL (a container image):
    # the fix is updating the image, not a local `se serve`.
    with_se_server_url("http://localhost:1") do
      SimpleEnglish::Client.stub :up?, true do
        SimpleEnglish::Client.stub :info, nil do
          SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "no spawn expected" } do
            _out, err = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
            end
            assert_match(/pull a newer image or rebuild/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_lints_against_an_outdated_daemon_when_jar_is_missing
    # No local Java: refusing the lint buys nothing. Warn and lint
    # against the old daemon instead.
    stale = {"version" => "0.1.0", "pid" => Process.pid,
             "gem_digest" => "old", "rules_digest" => "rules"}
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :up?, true do
        SimpleEnglish::Client.stub :info, stale do
          SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "no spawn expected" } do
            _out, err = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install_without_jar)
            end
            assert_match(/Linting against it meanwhile/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_lints_against_an_outdated_daemon_it_cannot_signal
    # A container daemon reports a pid from its own namespace, and a
    # daemon may belong to another user. TERMing either fails or is
    # wrong, and the replacement stalls on the occupied port:
    # warn and lint instead.
    stale = {"version" => "0.1.0", "pid" => 2**30,
             "gem_digest" => "old", "rules_digest" => "rules"}
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :up?, true do
        SimpleEnglish::Client.stub :info, stale do
          SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "no spawn expected" } do
            _out, err = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
            end
            assert_match(/not signalable from here/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_lints_against_an_outdated_daemon_when_java_is_missing
    # The jar is cached but java is gone (a brew upgrade removed it):
    # the child takeover stops the old daemon, then its own boot dies
    # on SetupError, and nothing is left to lint against. Preflight,
    # warn, keep linting.
    stale = {"version" => "0.1.0", "pid" => Process.pid,
             "gem_digest" => "old", "rules_digest" => "rules"}
    dir = Dir.mktmpdir
    (@tmpdirs ||= []) << dir
    lt = File.join(dir, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
    FileUtils.mkdir_p(lt)
    FileUtils.touch(File.join(lt, "languagetool-server.jar"))
    install = SimpleEnglish::Install.new(cache_dir: dir)
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :up?, true do
        SimpleEnglish::Client.stub :info, stale do
          SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "no spawn expected" } do
            _out, err = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install)
            end
            assert_match(/java not found/, err)
            assert_match(/Linting against it meanwhile/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_never_downgrades_a_newer_daemon
    # A newer daemon behind the default port belongs to a project
    # that bundles a newer gem. Restarting it boots this caller's
    # older build in its place, so warn, lint, and leave it alone.
    newer = {"version" => "9.9.9", "pid" => 4242,
             "gem_digest" => "other", "rules_digest" => "rules"}
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :up?, true do
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
  end

  def test_ensure_up_restarts_a_same_version_daemon_with_different_code
    # A dev checkout beside the installed gem: same version, different
    # code. The version cannot pick a winner, and the digest says the
    # running code is not this code, so restart.
    twin = {"version" => SimpleEnglish::VERSION, "pid" => Process.pid,
            "gem_digest" => "other", "rules_digest" => "rules"}
    fresh = twin.merge("gem_digest" => SimpleEnglish::Fingerprint.gem)
    answers = [twin, twin]
    spawned = false
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :up?, true do
        SimpleEnglish::Client.stub :info, ->(base_url: nil) { answers.shift || fresh } do
          SimpleEnglish::Client.stub :spawn_daemon, -> { spawned = true } do
            _out, err = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
            end
            assert spawned
            assert_match(/different code than this install/, err)
            assert_match(/restarting/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_skips_the_spawn_when_a_concurrent_repair_won
    # Two lints saw the same stale digest. The loser waits on the
    # restart lock, re-reads the handshake, finds the fresh digest,
    # and lints: never a second takeover against the winner's daemon.
    stale = {"version" => "0.1.0", "pid" => Process.pid,
             "gem_digest" => "old", "rules_digest" => "rules"}
    fresh = stale.merge("gem_digest" => SimpleEnglish::Fingerprint.gem)
    answers = [stale]
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :up?, true do
        SimpleEnglish::Client.stub :info, ->(base_url: nil) { answers.shift || fresh } do
          SimpleEnglish::Client.stub :spawn_daemon,
            -> { flunk "the fresh daemon must not be replaced" } do
            _out, = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
            end
          end
        end
      end
    end
  end

  def test_the_lock_loser_warns_when_the_winner_staged_other_rules
    # The winner linted from another project: the daemon runs fresh
    # code with that project's rules. The waiting lint must still get
    # the stale-rules warning, not a silent lint against foreign rules.
    winner = {"version" => SimpleEnglish::VERSION, "pid" => Process.pid,
              "gem_digest" => SimpleEnglish::Fingerprint.gem,
              "rules_digest" => "winner project's rules"}
    answers = [winner.merge("gem_digest" => "old")]
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :up?, true do
        SimpleEnglish::Client.stub :info, ->(base_url: nil) { answers.shift || winner } do
          SimpleEnglish::Client.stub :expected_rules_digest, "this project's rules" do
            SimpleEnglish::Client.stub :spawn_daemon,
              -> { flunk "the fresh daemon must not be replaced" } do
              _out, err = capture_io do
                assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
              end
              assert_match(/different rules/, err)
              assert_match(/se serve/, err)
            end
          end
        end
      end
    end
  end

  def test_ensure_up_warns_when_the_callers_rules_cannot_be_computed
    # A broken rule file in the lint caller's CWD must not lint
    # silently against the daemon's old rules.
    daemon = {"version" => SimpleEnglish::VERSION, "pid" => 4242,
              "gem_digest" => SimpleEnglish::Fingerprint.gem,
              "rules_digest" => "rules"}
    in_tmpdir(chdir: true) do |_dir|
      File.write("broken.xml", "<rules lang=\"en\">")
      File.write(".simple-english.yml", "rules: [broken.xml]\n")
      with_se_server_url(nil) do
        SimpleEnglish::Client.stub :up?, true do
          SimpleEnglish::Client.stub :info, daemon do
            _out, err = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
            end
            assert_match(/could not compare the daemon's rules/, err)
            assert_match(/broken\.xml/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_restarts_an_outdated_daemon
    stale = {"version" => "0.1.0", "pid" => Process.pid,
             "gem_digest" => "old", "rules_digest" => "rules"}
    fresh = {"version" => SimpleEnglish::VERSION, "pid" => 4243,
             "gem_digest" => SimpleEnglish::Fingerprint.gem,
             "rules_digest" => "rules"}
    answers = [stale, stale]
    spawned = false
    with_se_server_url(nil) do
      SimpleEnglish::Client.stub :up?, true do
        SimpleEnglish::Client.stub :info, ->(base_url: nil) { answers.shift || fresh } do
          SimpleEnglish::Client.stub :spawn_daemon, -> { spawned = true } do
            _out, err = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
            end
            assert_match(/different code than this install \(se 0\.1\.0\), restarting/, err)
            assert spawned
          end
        end
      end
    end
  end

  def test_ensure_up_never_restarts_a_daemon_behind_se_server_url
    stale = {"version" => "0.1.0", "pid" => 4242,
             "gem_digest" => "old", "rules_digest" => "rules"}
    with_se_server_url("http://localhost:1") do
      SimpleEnglish::Client.stub :up?, true do
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
  end

  def test_ensure_up_warns_when_rules_differ_but_gem_matches
    daemon = {"version" => SimpleEnglish::VERSION, "pid" => 4242,
              "gem_digest" => SimpleEnglish::Fingerprint.gem,
              "rules_digest" => "boot-time rules"}
    SimpleEnglish::Client.stub :up?, true do
      SimpleEnglish::Client.stub :info, daemon do
        SimpleEnglish::Client.stub :expected_rules_digest, "this project's rules" do
          SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "restart stays explicit" } do
            _out, err = capture_io do
              assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
            end
            assert_match(/Run `se serve` to reload/, err)
          end
        end
      end
    end
  end

  def test_ensure_up_is_quiet_when_everything_matches
    daemon = {"version" => SimpleEnglish::VERSION, "pid" => 4242,
              "gem_digest" => SimpleEnglish::Fingerprint.gem,
              "rules_digest" => "rules"}
    SimpleEnglish::Client.stub :up?, true do
      SimpleEnglish::Client.stub :info, daemon do
        SimpleEnglish::Client.stub :expected_rules_digest, "rules" do
          _out, err = capture_io do
            assert SimpleEnglish::Client.ensure_up(install: install_with_jar)
          end
          assert_empty err
        end
      end
    end
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

  def install_without_jar
    dir = Dir.mktmpdir
    (@tmpdirs ||= []) << dir
    SimpleEnglish::Install.new(cache_dir: dir)
  end

  def install_with_jar
    dir = Dir.mktmpdir
    (@tmpdirs ||= []) << dir
    lt = File.join(dir, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
    FileUtils.mkdir_p(lt)
    FileUtils.touch(File.join(lt, "languagetool-server.jar"))
    # Any real binary stands in for java: the restart path only
    # checks that one exists, and the spawn is stubbed in these tests.
    SimpleEnglish::Install.new(cache_dir: dir, java: RbConfig.ruby)
  end

  def teardown
    Array(@tmpdirs).each { |dir| FileUtils.remove_entry(dir) }
  end
end
