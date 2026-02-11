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

    # Returns the parser errors.
    getter errors : Array(ParserError)

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

    # parse_keypress parses a keypress command.
    #
    #	Key[@<time>] [count]
    private def parse_keypress(type : Token::Type) : Command
      cmd = Command.new(type)
      cmd.options = parse_speed
      cmd.args = parse_repeat
      cmd
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

    # parse_output parses an output command.
    # An output command takes a file path to which to output.
    #
    #	Output <path>
    private def parse_output : Command
      cmd = Command.new(Token::OUTPUT)

      if @peek.type != Token::STRING
        @errors << ParserError.new(@cur, "Expected file path after output")
        return cmd
      end

      ext = File.extname(@peek.literal)
      if !ext.empty?
        cmd.options = ext
      else
        cmd.options = ".png"
        unless @peek.literal.ends_with?('/')
          @errors << ParserError.new(@peek, "Expected folder with trailing slash")
        end
      end

      cmd.args = @peek.literal
      next_token
      cmd
    end

    # parse_sleep parses a sleep command.
    # A sleep command takes a time for how long to sleep.
    #
    #	Sleep <time>
    private def parse_sleep : Command
      cmd = Command.new(Token::SLEEP)
      cmd.args = parse_time
      cmd
    end

    # parse_type parses a type command.
    #
    #	Type "string"
    private def parse_type : Command
      cmd = Command.new(Token::TYPE)

      cmd.options = parse_speed

      if @peek.type != Token::STRING
        @errors << ParserError.new(@peek, "#{@cur.literal} expects string")
      end

      while @peek.type == Token::STRING
        next_token
        cmd.args += @cur.literal

        # If the next token is a string, add a space between them.
        # Since tokens must be separated by a whitespace, this is most likely
        # what the user intended.
        #
        # Although it is possible that there may be multiple spaces / tabs between
        # the tokens, however if the user was intending to type multiple spaces
        # they would need to use a string literal.

        if @peek.type == Token::STRING
          cmd.args += " "
        end
      end

      cmd
    end

    # parse_ctrl parses a control command.
    # A control command takes one or multiples characters and/or modifiers to type while ctrl is held down.
    #
    #	Ctrl[+Alt][+Shift]+<char>
    #	E.g:
    #	Ctrl+Shift+O
    #	Ctrl+Alt+Shift+P
    private def parse_ctrl : Command
      args = [] of String

      in_modifier_chain = true
      while @peek.type == Token::PLUS
        next_token
        peek = @peek

        # Get key from keywords and check if it's a valid modifier
        if k = Token::KEYWORDS[peek.literal]?
          if Token.modifier?(k)
            unless in_modifier_chain
              @errors << ParserError.new(@cur, "Modifiers must come before other characters")
              # Clear args so the error is returned
              args.clear
              next
            end

            args << peek.literal
            next_token
            next
          end
        end

        in_modifier_chain = false

        # Add key argument.
        case
        when peek.type == Token::ENTER,
             peek.type == Token::SPACE,
             peek.type == Token::BACKSPACE,
             peek.type == Token::MINUS,
             peek.type == Token::AT,
             peek.type == Token::LEFT_BRACKET,
             peek.type == Token::RIGHT_BRACKET,
             peek.type == Token::CARET,
             peek.type == Token::BACKSLASH,
             peek.type == Token::STRING && peek.literal.size == 1
          args << peek.literal
        else
          # Key arguments with len > 1 are not valid
          @errors << ParserError.new(@cur, "Not a valid modifier")
          @errors << ParserError.new(@cur, "Invalid control argument: #{@cur.literal}")
        end

        next_token
      end

      if args.empty?
        @errors << ParserError.new(@cur, "Expected control character with args, got #{@cur.literal}")
      end

      ctrl_args = args.join(" ")
      Command.new(Token::CTRL, "", ctrl_args)
    end

    # parse_alt parses an alt command.
    # An alt command takes a character to type while the modifier is held down.
    #
    #	Alt+<character>
    private def parse_alt : Command
      if @peek.type == Token::PLUS
        next_token
        if @peek.type == Token::STRING ||
           @peek.type == Token::ENTER ||
           @peek.type == Token::LEFT_BRACKET ||
           @peek.type == Token::RIGHT_BRACKET ||
           @peek.type == Token::TAB
          c = @peek.literal
          next_token
          return Command.new(Token::ALT, "", c)
        end
      end

      @errors << ParserError.new(@cur, "Expected alt character, got #{@cur.literal}")
      Command.new(Token::ALT)
    end

    # parse_shift parses a shift command.
    # A shift command takes one character and types while shift is held down.
    #
    #	Shift+<char>
    #	E.g.
    #	Shift+A
    #	Shift+Tab
    #	Shift+Enter
    private def parse_shift : Command
      if @peek.type == Token::PLUS
        next_token
        if @peek.type == Token::STRING ||
           @peek.type == Token::ENTER ||
           @peek.type == Token::LEFT_BRACKET ||
           @peek.type == Token::RIGHT_BRACKET ||
           @peek.type == Token::TAB
          c = @peek.literal
          next_token
          return Command.new(Token::SHIFT, "", c)
        end
      end

      @errors << ParserError.new(@cur, "Expected shift character, got #{@cur.literal}")
      Command.new(Token::SHIFT)
    end

    # parse_hide parses a Hide command.
    #
    #	Hide
    private def parse_hide : Command
      Command.new(Token::HIDE)
    end

    # parse_require parses a Require command.
    #
    #	Require
    private def parse_require : Command
      cmd = Command.new(Token::REQUIRE)

      if @peek.type != Token::STRING
        @errors << ParserError.new(@peek, "#{@cur.literal} expects one string")
      end

      cmd.args = @peek.literal
      next_token

      cmd
    end

    # parse_show parses a Show command.
    #
    #	Show
    private def parse_show : Command
      Command.new(Token::SHOW)
    end

    # parse_wait parses a wait command.
    private def parse_wait : Command
      cmd = Command.new(Token::WAIT)

      if @peek.type == Token::PLUS
        next_token
        if @peek.type != Token::STRING || (@peek.literal != "Line" && @peek.literal != "Screen")
          @errors << ParserError.new(@peek, "Wait+ expects Line or Screen")
          return cmd
        end
        cmd.args = @peek.literal
        next_token
      else
        cmd.args = "Line"
      end

      cmd.options = parse_speed
      if !cmd.options.empty?
        # TODO: Validate duration is positive
        # In Go: dur, _ := time.ParseDuration(cmd.Options)
        # if dur <= 0 { error }
        # For now, we'll skip validation
      end

      if @peek.type != Token::REGEX
        # fallback to default
        return cmd
      end
      next_token
      begin
        Regex.new(@cur.literal)
      rescue ex
        @errors << ParserError.new(@cur, "Invalid regular expression '#{@cur.literal}': #{ex.message}")
        return cmd
      end

      cmd.args += " " + @cur.literal

      cmd
    end

    # parse_source parses source command.
    private def parse_source : Array(Command)
      cmd = Command.new(Token::SOURCE)

      if @peek.type != Token::STRING
        @errors << ParserError.new(@cur, "Expected path after Source")
        next_token
        return [cmd]
      end

      src_path = @peek.literal

      # Check if path has .tape extension
      ext = File.extname(src_path)
      if ext != ".tape"
        @errors << ParserError.new(@peek, "Expected file with .tape extension")
        next_token
        return [cmd]
      end

      # Check if tape exists
      unless File.exists?(src_path)
        not_found_err = "File #{src_path} not found"
        @errors << ParserError.new(@peek, not_found_err)
        next_token
        return [cmd]
      end

      # Check if source tape contains nested Source command
      begin
        src_content = File.read(src_path)
      rescue ex
        read_err = "Unable to read file: #{src_path}"
        @errors << ParserError.new(@peek, read_err)
        next_token
        return [cmd]
      end

      # Check source tape is NOT empty
      if src_content.empty?
        read_err = "Source tape: #{src_path} is empty"
        @errors << ParserError.new(@peek, read_err)
        next_token
        return [cmd]
      end

      src_lexer = Lexer.new(src_content)
      src_parser = Parser.new(src_lexer)

      # Check not nested source
      src_cmds = src_parser.parse
      src_cmds.each do |src_cmd|
        if src_cmd.type == Token::SOURCE
          @errors << ParserError.new(@peek, "Nested Source detected")
          next_token
          return [cmd]
        end
      end

      # Check src errors
      src_errors = src_parser.errors
      if src_errors.size > 0
        @errors << ParserError.new(@peek, "#{src_path} has #{src_errors.size} errors")
        next_token
        return [cmd]
      end

      filtered = [] of Command
      src_cmds.each do |src_cmd|
        # Output have to be avoid in order to not overwrite output of the original tape.
        if src_cmd.type == Token::SOURCE || src_cmd.type == Token::OUTPUT
          next
        end
        filtered << src_cmd
      end

      next_token
      filtered
    end

    # parse_screenshot parses screenshot command.
    # Screenshot command takes a file path for storing screenshot.
    #
    #	Screenshot <path>
    private def parse_screenshot : Command
      cmd = Command.new(Token::SCREENSHOT)

      if @peek.type != Token::STRING
        @errors << ParserError.new(@cur, "Expected path after Screenshot")
        next_token
        return cmd
      end

      path = @peek.literal

      # Check if path has .png extension
      ext = File.extname(path)
      if ext != ".png"
        @errors << ParserError.new(@peek, "Expected file with .png extension")
        next_token
        return cmd
      end

      cmd.args = path
      next_token

      cmd
    end

    # parse_copy parses a copy command
    # A copy command takes a string to the clipboard
    #
    #	Copy "string"
    private def parse_copy : Command
      cmd = Command.new(Token::COPY)

      if @peek.type != Token::STRING
        @errors << ParserError.new(@peek, "#{@cur.literal} expects string")
      end
      while @peek.type == Token::STRING
        next_token
        cmd.args += @cur.literal

        # If the next token is a string, add a space between them.
        # Since tokens must be separated by a whitespace, this is most likely
        # what the user intended.
        #
        # Although it is possible that there may be multiple spaces / tabs between
        # the tokens, however if the user was intending to type multiple spaces
        # they would need to use a string literal.

        if @peek.type == Token::STRING
          cmd.args += " "
        end
      end
      cmd
    end

    # parse_paste parses paste command
    # Paste Command the string from the clipboard buffer.
    #
    #	Paste
    private def parse_paste : Command
      Command.new(Token::PASTE)
    end

    # parse_env parses Env command
    # Env command takes in a key-value pair which is set.
    #
    #	Env key "value"
    private def parse_env : Command
      cmd = Command.new(Token::ENV)

      cmd.options = @peek.literal
      next_token

      if @peek.type != Token::STRING
        @errors << ParserError.new(@peek, "#{@cur.literal} expects string")
      end

      cmd.args = @peek.literal
      next_token

      cmd
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
