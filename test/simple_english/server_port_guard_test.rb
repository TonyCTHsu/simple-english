# frozen_string_literal: true

require_relative "test_helper"

require "socket"

class ServerPortGuardTest < Minitest::Test
  def test_serve_refuses_occupied_port
    blocker = TCPServer.new("localhost", 0)
    port = blocker.addr[1]
    error = assert_raises(SimpleEnglish::Server::PortInUse) do
      SimpleEnglish::Server.start(port: port)
    end
    assert_equal "port #{port} is already in use.", error.message
  ensure
    blocker&.close
  end

  def test_serve_refuses_occupied_inner_port
    # Find a free port whose predecessor is also free, then block the
    # port so start() sees port + 1 occupied and raises before booting.
    50.times do
      probe = TCPServer.new("localhost", 0)
      port = probe.addr[1]
      probe.close
      begin
        outer = TCPServer.new("localhost", port - 1)
      rescue Errno::EADDRINUSE
        next
      end
      outer.close
      blocker = TCPServer.new("localhost", port)
      error = assert_raises(SimpleEnglish::Server::PortInUse) do
        SimpleEnglish::Server.start(port: port - 1)
      end
      assert_equal "port #{port} is already in use.", error.message
      return
    ensure
      blocker&.close
    end
    flunk "found no free adjacent port pair"
  end
end
