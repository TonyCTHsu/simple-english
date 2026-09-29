# frozen_string_literal: true

require_relative "test_helper"

class ServerTakeoverTest < Minitest::Test
  def test_takeover_signals_the_reported_pid_and_waits_it_out
    child = Process.spawn(RbConfig.ruby, "-e", "sleep 30")
    answers = [{"pid" => child, "gem_digest" => "old"}]
    SimpleEnglish::Client.stub :info, ->(base_url:) { answers.shift } do
      SimpleEnglish::Server.takeover(28291)
    end
    assert_reaped(child)
  end

  def test_takeover_leaves_a_foreign_port_holder_alone
    SimpleEnglish::Client.stub :info, nil do
      # No raise, no kill: the caller hits the PortInUse error instead.
      assert_nil SimpleEnglish::Server.takeover(28291)
    end
  end

  def test_serve_leaves_the_old_daemon_alive_when_the_replacement_cannot_stage
    # A reload with a broken rule file must not stop the healthy
    # daemon first: staging and the install preflight run before the
    # takeover, so a failed reload leaves the old daemon linting.
    in_tmpdir(chdir: true) do |_dir|
      File.write("broken.xml", "<rules lang=\"en\"><rule id=\"X\">")
      File.write(".simple-english.yml", "rules: [broken.xml]\n")
      child = Process.spawn(RbConfig.ruby, "-e", "sleep 30")
      SimpleEnglish::Client.stub :info, ->(base_url:) { {"pid" => child, "gem_digest" => "old"} } do
        error = assert_raises(SimpleEnglish::Server::ServerError) do
          SimpleEnglish::Server.start(port: 28295)
        end
        assert_match(/broken\.xml/, error.message)
      end
      assert_nil Process.wait(child, Process::WNOHANG),
        "the old daemon must survive a failed reload"
      Process.kill("TERM", child)
      Process.wait(child)
    end
  end

  def test_takeover_refuses_a_pid_off_the_wire_that_is_not_a_positive_integer
    # The handshake is unauthenticated: a foreign responder can name
    # pid 0 (the caller's process group) or anything else. Only a
    # positive integer pid is ever TERMed.
    [0, -1, "1", 1.5].each do |pid|
      answers = [{"pid" => pid, "gem_digest" => "x"}]
      SimpleEnglish::Client.stub :info, ->(base_url:) { answers.shift } do
        assert_nil SimpleEnglish::Server.takeover(28291)
      end
    end
  end

  private

  def assert_reaped(pid)
    reaped = nil
    50.times do
      reaped = Process.wait(pid, Process::WNOHANG)
      break if reaped
      sleep 0.1
    end
    refute_nil reaped, "child still running after takeover"
  end
end
