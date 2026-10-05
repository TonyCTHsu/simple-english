# frozen_string_literal: true

require_relative "test_helper"

require "socket"

class ServerPortGuardTest < Minitest::Test
  def test_port_free_reports_an_ipv6_only_listener
    # A listener on ::1 alone must count as occupied: the guard
    # probes both families, an IPv4-only probe misses it.
    blocker = begin
      TCPServer.new("::1", 0)
    rescue Errno::EADDRNOTAVAIL, Errno::EAFNOSUPPORT, SocketError
      skip "this host has no IPv6 loopback"
    end
    port = blocker.addr[1]
    refute SimpleEnglish::Server.port_free?(port)
  ensure
    blocker&.close
  end

  def test_serve_refuses_occupied_port
    # The install is faked so the occupied-port guard decides the outcome.
    fake_install do |install|
      blocker = TCPServer.new("localhost", 0)
      port = blocker.addr[1]
      error = assert_raises(SimpleEnglish::Server::PortInUse) do
        SimpleEnglish::Server.start(port: port, install: install)
      end
      assert_equal "port #{port} is already in use.", error.message
    ensure
      blocker&.close
    end
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
      fake_install do |install|
        error = assert_raises(SimpleEnglish::Server::PortInUse) do
          SimpleEnglish::Server.start(port: port - 1, install: install)
        end
        assert_equal "port #{port} is already in use.", error.message
      end
      return
    ensure
      blocker&.close
    end
    flunk "found no free adjacent port pair"
  end
end
