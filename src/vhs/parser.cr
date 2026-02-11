require "./lexer"
require "./token"
require "regex"

module Vhs
  class Parser
    @errors = [] of ParserError

    def initialize(@lexer : Lexer)
      @cur = Token::Token.new(Token::EOF, "", 0, 0)
      @peek = Token::Token.new(Token::EOF, "", 0, 0)
      # Read two tokens, so cur and peek are both set.
      next_token
      next_token
    end

    # ParserError represents an error with parsing a tape file.
    # It tracks the token causing the error and a human readable error message.
    class ParserError
      getter token : Token::Token
      getter message : String

      def initialize(@token, @message)
      end

      def to_s(io : IO) : Nil
        io << sprintf("%2d:%-2d │ %s", token.line, token.column, message)
      end
    end

    # Command represents a command with options and arguments.
    class Command
      property type : Token::Type
      property options : String
      property args : String
      property source : String

      def initialize(@type, @options = "", @args = "", @source = "")
      end

      def to_s(io : IO) : Nil
        if !options.empty?
          io << type << " " << options << " " << args
        else
          io << type << " " << args
        end
      end
    end

    # Parse takes an input string provided by the lexer and parses it into a
    # list of commands.
    def parse : Array(Command)
      cmds = [] of Command

      while @cur.type != Token::EOF
        if @cur.type == Token::COMMENT
          next_token
          next
        end
        cmds.concat parse_command
        next_token
      end

      cmds
    end

    # parse_command parses a command.
    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_command : Array(Command)
      case @cur.type
      when Token::SPACE,
           Token::BACKSPACE,
           Token::DELETE,
           Token::INSERT,
           Token::ENTER,
           Token::ESCAPE,
           Token::TAB,
           Token::DOWN,
           Token::LEFT,
           Token::RIGHT,
           Token::UP,
           Token::PAGE_UP,
           Token::PAGE_DOWN
        [parse_keypress(@cur.type)]
      when Token::SET
        [parse_set]
      when Token::OUTPUT
        [parse_output]
      when Token::SLEEP
        [parse_sleep]
      when Token::TYPE
        [parse_type]
      when Token::CTRL
        [parse_ctrl]
      when Token::ALT
        [parse_alt]
      when Token::SHIFT
        [parse_shift]
      when Token::HIDE
        [parse_hide]
      when Token::REQUIRE
        [parse_require]
      when Token::SHOW
        [parse_show]
      when Token::WAIT
        [parse_wait]
      when Token::SOURCE
        parse_source
      when Token::SCREENSHOT
        [parse_screenshot]
      when Token::COPY
        [parse_copy]
      when Token::PASTE
        [parse_paste]
      when Token::ENV
        [parse_env]
      else
        @errors << ParserError.new(@cur, "Invalid command: #{@cur.literal}")
        [Command.new(Token::ILLEGAL)]
      end
    end

    # Advances the parser to the next token.
    private def next_token
      @cur = @peek
      @peek = @lexer.next_token
    end

    # TODO: Implement parse_keypress, parse_set, parse_output, etc.
    private def parse_keypress(type : Token::Type) : Command
      Command.new(type)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_set : Command
      cmd = Command.new(Token::SET)

      if Token.setting?(@peek.type)
        cmd.options = @peek.literal
      else
        @errors << ParserError.new(@peek, "Unknown setting: #{@peek.literal}")
      end
      next_token

      case @cur.type
      when Token::WAIT_TIMEOUT
        cmd.args = parse_time
      when Token::WAIT_PATTERN
        cmd.args = @peek.literal
        begin
          Regex.new(@peek.literal)
        rescue ex
          @errors << ParserError.new(@peek, "Invalid regexp pattern: #{@peek.literal}")
        end
        next_token
      when Token::LOOP_OFFSET
        cmd.args = @peek.literal
        next_token
        # Allow LoopOffset without '%'
        # Set LoopOffset 20
        cmd.args += "%"
        if @peek.type == Token::PERCENT
          next_token
        end
      when Token::TYPING_SPEED
        cmd.args = @peek.literal
        next_token
        # Allow TypingSpeed to have bare units (e.g. 10ms)
        # Set TypingSpeed 10ms
        if @peek.type == Token::MILLISECONDS || @peek.type == Token::SECONDS
          cmd.args += @peek.literal
          next_token
        elsif cmd.options == "TypingSpeed"
          cmd.args += "s"
        end
      when Token::WINDOW_BAR
        cmd.args = @peek.literal
        next_token

        window_bar = @cur.literal
        unless valid_window_bar?(window_bar)
          @errors << ParserError.new(@cur, "#{window_bar} is not a valid bar style.")
        end
      when Token::MARGIN_FILL
        cmd.args = @peek.literal
        next_token

        margin_fill = @cur.literal

        # Check if margin color is a valid hex string
        if margin_fill.starts_with?('#')
          hex = margin_fill[1..]
          if hex.size != 6 || hex.to_i?(16).nil?
            @errors << ParserError.new(@cur, "\"#{margin_fill}\" is not a valid color.")
          end
        end
      when Token::CURSOR_BLINK
        cmd.args = @peek.literal
        next_token

        if @cur.type != Token::BOOLEAN
          @errors << ParserError.new(@cur, "expected boolean value.")
        end
      else
        cmd.args = @peek.literal
        next_token
      end

      cmd
    end

    private def parse_output : Command
      Command.new(Token::OUTPUT)
    end

    private def parse_sleep : Command
      Command.new(Token::SLEEP)
    end

    private def parse_type : Command
      Command.new(Token::TYPE)
    end

    private def parse_ctrl : Command
      Command.new(Token::CTRL)
    end

    private def parse_alt : Command
      Command.new(Token::ALT)
    end

    private def parse_shift : Command
      Command.new(Token::SHIFT)
    end

    private def parse_hide : Command
      Command.new(Token::HIDE)
    end

    private def parse_require : Command
      Command.new(Token::REQUIRE)
    end

    private def parse_show : Command
      Command.new(Token::SHOW)
    end

    private def parse_wait : Command
      Command.new(Token::WAIT)
    end

    private def parse_source : Array(Command)
      [Command.new(Token::SOURCE)]
    end

    private def parse_screenshot : Command
      Command.new(Token::SCREENSHOT)
    end

    private def parse_copy : Command
      Command.new(Token::COPY)
    end

    private def parse_paste : Command
      Command.new(Token::PASTE)
    end

    private def parse_env : Command
      Command.new(Token::ENV)
    end

    # parse_speed parses a typing speed indication.
    #
    # i.e. @<time>
    #
    # This is optional (defaults to 100ms), thus skips (rather than error-ing)
    # if the typing speed is not specified.
    private def parse_speed : String
      if @peek.type == Token::AT
        next_token
        parse_time
      else
        ""
      end
    end

    # parse_repeat parses an optional repeat count for a command.
    #
    # i.e. Backspace [count]
    #
    # This is optional (defaults to 1), thus skips (rather than error-ing)
    # if the repeat count is not specified.
    private def parse_repeat : String
      if @peek.type == Token::NUMBER
        count = @peek.literal
        next_token
        count
      else
        "1"
      end
    end

    # parse_time parses a time argument.
    #
    #	<number>[ms]
    private def parse_time : String
      if @peek.type == Token::NUMBER
        t = @peek.literal
        next_token
      else
        @errors << ParserError.new(@cur, "Expected time after #{@cur.literal}")
        return ""
      end

      # Allow TypingSpeed to have bare units (e.g. 50ms, 100ms)
      if @peek.type == Token::MILLISECONDS || @peek.type == Token::SECONDS || @peek.type == Token::MINUTES
        t += @peek.literal
        next_token
      else
        t += "s"
      end

      t
    end

    private def valid_window_bar?(w : String) : Bool
      w == "" ||
        w == "Colorful" || w == "ColorfulRight" ||
        w == "Rings" || w == "RingsRight"
    end
  end
end
