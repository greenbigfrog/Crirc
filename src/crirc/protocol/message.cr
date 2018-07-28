enum UserType
  Empty
  Mod
  GlobalMod
  Admin
  Staff
end

# `Message` is the object that parse the raw TCP body as a IRC message.
#
# Message are a IRC core part. They contain a command, the arguments, and
# the message (last argument in the IRC protocol).
# TODO: improve the message to appear in as the last argument. cf: fast_irc
class Crirc::Protocol::Message
  # Raw message without parsing
  getter raw : String

  # The Badges of author ("broadcaster", "moderator")
  getter badges : String?

  # The amount of cheers/Bits employed by the user
  # Only sent for Bits messages
  getter bits : String?

  # The display color of author as hex color value ("#9ACD32")
  getter color : String?

  # The display name of the author ("user1")
  # Nil if it hasn't ben set.
  getter display_name : String?

  # Comma-seperated list of emotes
  # (Syntax: `<emote ID>:<first index>-<last index>,<another first index>-<another last index>/<another emote ID>:<first index>-<last index>...`)
  getter emotes : String?

  # The Twitch Message ID
  getter message_id : String?

  # The Twitch Thread ID
  getter thread_id : String?

  # Whether the user has Twitch Turbo or not
  getter turbo : Bool?

  # The author's Twitch ID
  getter user_id : Int64?

  # The user's type (:empty, :mod, :global_mod, :admin, :staff)
  getter user_type : UserType?

  # The chat language when broadcaster language mode is enabled; otherwise, empty
  getter broadcaster_lang : String?

  # R9K mode. If enabled, messages with more than 9 characters must be unique
  getter r9k : Bool?

  # The number of seconds chatters without moderator privileges must wait between sending messages.
  getter slow : Int32?

  # Subscribers-only mode
  # If enabled, only subscribers and moderators can chat
  getter subs_only : Bool?

  # Undocumented Twitch shit
  getter emote_only : Bool?
  getter followers_only : String?
  getter rituals : String?
  getter emote_sets : String?

  # The channel ID
  getter room_id : Int32?

  # true if the user has the moderator badge
  getter mod : Bool?

  # true if the user has the subscriber badge
  getter subsriber : Bool?

  # Timestamp the server received the message
  getter tmi_sent_ts : String?

  # Duration of the timeout, in seconds. If omitted, the ban is permanent.
  getter ban_duration : String?

  # The moderator’s reason for the timeout or ban.
  getter ban_reason : String?

  # Source of the message (ex: "0", "abc@xyz", ...)
  getter source : String

  # The command ("PRIVMSG", "PING", ...)
  getter command : String

  # The arguments as a string ("user1 +0", "pingmessage", ...)
  getter arguments : String?

  # The last argument when ":" ("This is a privmsg message", ...)
  getter message : String?

  REGEX = Regex.new(String.build do |io|
    io << "\\A"

    # PRIVMSG
    io << "(@"
    io << "(#{R_BADGES};)?"
    io << "(bits=(?<bits>\\w*);)?"
    io << "(#{R_COLOR};)?"
    io << "(#{R_DISPLAY_NAME};)?"
    io << "(emote-only=(?<emote_only>\\d+);)?"
    io << "(#{R_EMOTES};)?"
    io << "(message-id=(?<message_id>\\d+);)?"
    io << "(id=(?<message_id>[\\w-]*);)?"
    io << "(#{R_MOD};)?"
    io << "(room-id=(?<room_id>\\w*);)?"
    io << "(#{R_SUBSCRIBER};)?"
    io << "(#{R_TMI_SENT_TS};)?"
    io << "(thread-id=(?<thread_id>\\w*);)?"
    io << "(#{R_TURBO};)?"
    io << "(user-id=(?<user_id>\\d+);)?"
    io << "(#{R_USER_TYPE})?"
    io << " )?"

    # USERSTATE
    io << "(@"
    io << "(#{R_BADGES};)?"
    io << "(#{R_COLOR};)?"
    io << "(#{R_DISPLAY_NAME};)?"
    io << "(emote-sets=(?<emote_sets>\\w*);)?"
    io << "(#{R_EMOTES};)?"
    io << "(#{R_MOD};)?"
    io << "(#{R_SUBSCRIBER};)?"
    io << "(#{R_TURBO};)?"
    io << "(#{R_USER_TYPE})?"
    io << " )?"

    # ROOMSTATE
    io << "(@"
    io << "(broadcaster-lang=(?<broadcaster_lang>\\w*);)?"
    io << "(emote-only=(?<emote_only>\\d);)?"
    io << "(followers-only=(?<followers_only>-*\\d*);)?"
    io << "(r9k=(?<r9k>\\d);)?"
    io << "(rituals=(?<rituals>\\w*);)?"
    io << "(#{R_ROOM_ID};)?"
    io << "(slow=(?<slow>\\d*);)?"
    io << "(subs-only=(?<subs_only>\\d))?"
    io << " )?"

    # TODO USERNOTICE
    io << "(@"
    io << "(msg-id=(?<msg_id>\\w*))?"
    io << " )?"

    # TODO GLOBALUSERSTATE

    # CLEARCHAT
    io << "(@"
    io << "(ban-duration=(?<ban_duration>\\w*);)?"
    io << "(ban-reason=(?<ban_reason>\\w*);)?"
    io << "(#{R_TMI_SENT_TS};)?"
    io << "(#{R_ROOM_ID};)?"
    io << " )?"

    io << "#{R_SRC}?"
    io << "#{R_CMD}"
    io << "#{R_ARG}?"
    io << "#{R_MSG}?"
    io << "\\Z"
  end
  )

  R_COLOR        = "color=(?<color>#?[[:xdigit:]]*)"
  R_DISPLAY_NAME = "display-name=(?<display_name>\\w*)"
  R_EMOTES       = "emotes=(?<emotes>\[\\w:-]*)"
  R_MOD          = "mod=(?<mod>\\d)"
  R_SUBSCRIBER   = "subscriber=(?<subscriber>\\d)"
  R_TURBO        = "turbo=(?<turbo>\\w*)"
  R_USER_TYPE    = "user-type=(?<user_type>\\w*)"
  R_BADGES       = "badges=(?<badges>[(\\w*\\/?\\d)|,]*)"
  R_TMI_SENT_TS  = "tmi-sent-ts=(?<ts>\\d*)"
  R_ROOM_ID      = "room-id=(?<room_id>\\d*)"

  R_SRC     = "(\\:(?<src>[^[:space:]]+) )"
  R_CMD     = "(?<cmd>[A-Z]+|\\d{3})"
  R_ARG_ONE = "(?:[^: ][^ ]*)"
  R_ARG     = "(?: (?<arg>#{R_ARG_ONE}(?: #{R_ARG_ONE})*))"
  R_MSG     = "(?: \\:(?<msg>.+)?)"

  def initialize(@raw)
    m = raw.strip.match(REGEX)
    begin
      raise ParsingError.new "The message (#{@raw}) is invalid" if m.nil?
    rescue
      pp REGEX
      puts @raw
      exit
    end
    exit if m.nil?

    raise Exception.new("Twitch gave a NOTICE: #{m["msg_id"]}") if m["msg_id"]?

    # PRIVMSG
    @badges = m["badges"]?
    @bits = m["bits"]?
    @color = m["color"]?
    @emotes = m["emotes"]?
    @emote_only = m["emote_only"]? == 1 ? true : false
    @tmi_sent_ts = m["tmi_sent_ts"]?
    @subscriber = m["subscriber"]? == 1 ? true : false
    @mod = m["mod"]? == 1 ? true : false
    @message_id = m["message_id"]?
    @thread_id = m["thread_id"]?
    @turbo = m["turbo"]? == 1 ? true : false
    @user_id = m["user_id"]?.try &.to_i64
    if m["user_type"]?
      @user_type = case m["user_type"]
                   when "mod"
                     UserType::Mod
                   when "global_mod"
                     UserType::GlobalMod
                   when "admin"
                     UserType::Admin
                   when "staff"
                     UserType::Staff
                   else
                     UserType::Empty
                   end
    end

    @emote_sets = m["emote_sets"]?

    # ROOMSTATE
    @broadcaster_lang = m["broadcaster_lang"]?
    @emote_only = m["emote_only"]? == 1 ? true : false
    @followers_only = m["followers_only"]?
    @r9k = m["r9k"]? == 1 ? true : false
    @rituals = m["rituals"]?
    @room_id = m["room_id"]?.try &.to_i32
    @slow = m["slow"]?.try &.to_i32
    @subs_only = m["subs_only"]? == 1 ? true : false

    # CLEARCHAT
    @ban_reason = m["ban_reason"]?
    @ban_duration = m["ban_duration"]?

    @source = m["src"]? || "0"
    @command = m["cmd"] # ? || raise InvalidMessage.new("No command to parse in \"#{raw}\"")
    @arguments = m["arg"]?
    @message = m["msg"]?
  end

  # Concatenation of `arguments` and `message`.
  # If the message exists, it is preceded by ':'
  #
  # ```
  # msg.raw_arguments # => "user1 +0 :do something"
  # ```
  def raw_arguments : String
    return "" if @arguments.nil? && @message.nil?
    return @arguments.to_s if @message.nil?
    return ":#{@message}" if @arguments.nil?
    return "#{@arguments} :#{@message}"
  end

  # The arguments formated into an Array.
  #
  # ```
  # msg.argument_list # => ["user1", "+0"]
  # ```
  def argument_list : Array(String)
    return Array(String).new if @arguments.nil? && @message.nil?
    return (@arguments.as(String)).split(" ") if @message.nil?
    return [@message.as(String)] if @arguments.nil?
    return (@arguments.as(String)).split(" ") << (@message.as(String))
  end

  class ParsingError < Exception; end
end
