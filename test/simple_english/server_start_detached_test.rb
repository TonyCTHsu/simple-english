# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "socket"

class ServerStartDetachedTest < Minitest::Test
  def test_spawns_a_plain_serve_and_returns_the_handshake
    port = free_port
    spawned = nil
    SimpleEnglish::Server.stub :takeover, nil do
      SimpleEnglish::Client.stub :spawn_daemon, ->(*args) { spawned = args } do
        SimpleEnglish::Client.stub :wait_for, ->(&block) { block.call } do
          SimpleEnglish::Client.stub :info, {"pid" => 4242} do
            in_tmpdir do |dir|
              daemon = SimpleEnglish::Server.start_detached(port: port,
                install: fake_install(dir))
              assert_equal 4242, daemon["pid"]
              assert_equal ["--port", port.to_s], spawned
            end
          end
        end
      end
    end
  end

  def test_forwards_the_dev_log_to_the_child_serve
    port = free_port
    spawned = nil
    SimpleEnglish::Server.stub :takeover, nil do
      SimpleEnglish::Client.stub :spawn_daemon, ->(*args) { spawned = args } do
        SimpleEnglish::Client.stub :wait_for, ->(&block) { block.call } do
          SimpleEnglish::Client.stub :info, {"pid" => 4242} do
            in_tmpdir do |dir|
              SimpleEnglish::Server.start_detached(port: port,
                install: fake_install(dir), dev_log: "daemon.log")
              assert_equal ["--port", port.to_s, "--dev-log", "daemon.log"], spawned
            end
          end
        end
      end
    end
  end

  def test_fails_fast_when_a_foreign_process_holds_the_port
    # A foreign holder does not answer the handshake, so the takeover
    # leaves it alone and the port check fires in milliseconds
    # instead of waiting out the spawn timeout.
    holder = TCPServer.new("127.0.0.1", 28291)
    in_tmpdir do |dir|
      SimpleEnglish::Client.stub :info, nil do
        SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "must not spawn" } do
          error = assert_raises(SimpleEnglish::Server::PortInUse) do
            SimpleEnglish::Server.start_detached(port: 28291,
              install: fake_install(dir))
          end
          assert_match(/28291/, error.message)
        end
      end
    end
  ensure
    holder&.close
  end

  def test_fails_fast_with_setup_message_when_the_jar_is_missing
    in_tmpdir do |dir|
      install = SimpleEnglish::Install.new(cache_dir: dir, java: RbConfig.ruby)
      SimpleEnglish::Client.stub :spawn_daemon, -> { flunk "must not spawn" } do
        error = assert_raises(SimpleEnglish::Install::SetupError) do
          SimpleEnglish::Server.start_detached(port: 28291, install: install)
        end
        assert_match(/Run `se setup`/, error.message)
      end
    end
  end

  private

  def fake_install(dir)
    lt = File.join(dir, "LanguageTool-#{SimpleEnglish::LanguageTool::LT_VERSION}")
    FileUtils.mkdir_p(lt)
    FileUtils.touch(File.join(lt, "languagetool-server.jar"))
    SimpleEnglish::Install.new(cache_dir: dir, java: RbConfig.ruby)
  end

  def free_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end
end
