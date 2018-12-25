require "socket"
require "openssl"
require "../controller/client"
require "./network"
require "../rate_limiter"

class Crirc::Network::Client
  include Network

  alias IrcSocket = TCPSocket | OpenSSL::SSL::Socket::Client

  getter nick : String
  getter ip : String
  getter port : UInt16
  getter ssl : Bool
  @socket : IrcSocket?
  getter user : String
  getter realname : String
  getter domain : String?
  getter pass : String?
  getter irc_server : String?
  getter read_timeout : UInt16
  getter write_timeout : UInt16
  getter keepalive : Bool
  getter limiter : RateLimiter(String)

  # default port is 6667 or 6697 if ssl is true
  def initialize(@nick : String, @ip, port = nil.as(UInt16?), @ssl = true, user = nil, realname = nil, @domain = nil, @pass = nil, @irc_server = nil,
                 @read_timeout = 120_u16, @write_timeout = 5_u16, @keepalive = true, @limiter : RateLimiter = RateLimiter(String).new)
    @port = port.to_u16 || (ssl ? 6697_u16 : 6667_u16)
    @user = user || @nick
    @realname = realname || @nick
    @domain ||= "0"
    @irc_server ||= "*"

    # TODO allow the different bot types here
    # https://dev.twitch.tv/docs/irc/guide/#command--message-limits
    @limiter.bucket(:whisper, 3_u32, 1.second, sub_buckets: [:whisper2])
    @limiter.bucket(:whisper2, 100_u32, 1.minute)

    # @limiter.bucket(:everything2, 20_u32, 30.seconds)
    # @limiter.bucket(:everything, 1_u32, 1.seconds, sub_buckets: [:everything2])
    @limiter.bucket(:everything2, 20_u32, 30.seconds)
    @limiter.bucket(:everything, 1_u32, 2.seconds, sub_buckets: [:everything2])
  end

  def socket
    raise "Socket is not set. Add `client.connect()` before using `client.socket`" if @socket.nil?
    @socket.as(IrcSocket)
  end

  # Connect to the server
  def connect
    tcp_socket = TCPSocket.new(@ip, @port)
    tcp_socket.read_timeout = @read_timeout
    tcp_socket.write_timeout = @write_timeout
    tcp_socket.keepalive = @keepalive
    @socket = tcp_socket
    @socket = OpenSSL::SSL::Socket::Client.new(tcp_socket) if @ssl
    self
  end

  # Start a new Controller::Client binded to the current object
  def start(&block)
    controller = Controller::Client.new(self)
    controller.init
    yield controller
  end

  # Wait and fetch the next incoming message
  def gets
    socket.gets
  end

  # Send a message to the server
  def puts(data)
    split_data = data.split(" ")
    if split_data.first == "PRIVMSG"
      case split_data[1]
      when "#jtv"
        @limiter.rate_limit(:whisper, "#jtv")
      else
        # Twitch Ratelimits are global
        @limiter.rate_limit(:everything, "abc")
      end
    end
    socket.puts data.strip # TODO: add \r\n
  end

  # End the connection
  def close
    socket.close
    @socket = nil
  end
end
