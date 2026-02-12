require "ultraviolet"
require "process"
require "random/secure"

module Vhs
  # Theme colors.
  BACKGROUND     = "#171717"
  FOREGROUND     = "#dddddd"
  BLACK          = "#282a2e" # ansi 0
  BRIGHT_BLACK   = "#4d4d4d" # ansi 8
  RED            = "#D74E6F" # ansi 1
  BRIGHT_RED     = "#FE5F86" # ansi 9
  GREEN          = "#31BB71" # ansi 2
  BRIGHT_GREEN   = "#00D787" # ansi 10
  YELLOW         = "#D3E561" # ansi 3
  BRIGHT_YELLOW  = "#EBFF71" # ansi 11
  BLUE           = "#8056FF" # ansi 4
  BRIGHT_BLUE    = "#9B79FF" # ansi 12
  MAGENTA        = "#ED61D7" # ansi 5
  BRIGHT_MAGENTA = "#FF7AEA" # ansi 13
  CYAN           = "#04D7D7" # ansi 6
  BRIGHT_CYAN    = "#00FEFE" # ansi 14
  WHITE          = "#bfbfbf" # ansi 7
  BRIGHT_WHITE   = "#e6e6e6" # ansi 15
  INDIGO         = "#5B56E0"

  # DefaultTheme is the default theme to use for recording demos and screenshots.
  DEFAULT_THEME = Theme.new(
    name: "",
    background: BACKGROUND,
    foreground: FOREGROUND,
    selection: "",
    cursor: FOREGROUND,
    cursor_accent: BACKGROUND,
    black: BLACK,
    bright_black: BRIGHT_BLACK,
    red: RED,
    bright_red: BRIGHT_RED,
    green: GREEN,
    bright_green: BRIGHT_GREEN,
    yellow: YELLOW,
    bright_yellow: BRIGHT_YELLOW,
    blue: BLUE,
    bright_blue: BRIGHT_BLUE,
    magenta: MAGENTA,
    bright_magenta: BRIGHT_MAGENTA,
    cyan: CYAN,
    bright_cyan: BRIGHT_CYAN,
    white: WHITE,
    bright_white: BRIGHT_WHITE
  )

  # Default constants
  DEFAULT_COLUMNS         =   80
  DEFAULT_HEIGHT          =  600
  DEFAULT_MAX_COLORS      =  256
  DEFAULT_PADDING         =   60
  DEFAULT_WINDOW_BAR_SIZE =   30
  DEFAULT_PLAYBACK_SPEED  =  1.0
  DEFAULT_WIDTH           = 1200
  DEFAULT_FONT_SIZE       =   22
  DEFAULT_TYPING_SPEED    = 50.milliseconds
  DEFAULT_LINE_HEIGHT     = 1.0
  DEFAULT_LETTER_SPACING  = 1.0
  DEFAULT_CURSOR_BLINK    = true
  DEFAULT_WAIT_TIMEOUT    = 15.seconds
  DEFAULT_FRAMERATE       = 50
  DEFAULT_STARTING_FRAME  =  1
  FONTS_SEPARATOR         = ","

  DEFAULT_FONT_FAMILY = with_symbols_fallback([
    "JetBrains Mono",
    "DejaVu Sans Mono",
    "Menlo",
    "Bitstream Vera Sans Mono",
    "Inconsolata",
    "Roboto Mono",
    "Hack",
    "Consolas",
    "ui-monospace",
    "monospace",
  ].join(FONTS_SEPARATOR))

  SYMBOLS_FALLBACK = [
    "Apple Symbols",
  ]

  private def self.with_symbols_fallback(font : String) : String
    font + FONTS_SEPARATOR + SYMBOLS_FALLBACK.join(FONTS_SEPARATOR)
  end

  # Default wait pattern regex
  DEFAULT_WAIT_PATTERN = />$/

  # Default shell (platform dependent, set later)
  DEFAULT_SHELL = {% if flag?(:win32) %} "cmd" {% else %} "bash" {% end %}

  # InvalidSyntaxError is returned when the parser encounters one or more errors.
  class InvalidSyntaxError < Exception
    getter errors : Array(Parser::ParserError)

    def initialize(@errors : Array(Parser::ParserError))
    end

    def message : String
      "parser: #{errors.size} error(s)"
    end
  end

  # Supported shells of VHS.
  BASH       = "bash"
  CMDEXE     = "cmd"
  FISH       = "fish"
  NUSHELL    = "nu"
  OSH        = "osh"
  POWERSHELL = "powershell"
  PWSH       = "pwsh"
  XONSH      = "xonsh"
  ZSH        = "zsh"

  # Shells contains a mapping from shell names to their Shell struct.
  SHELLS = {
    BASH => Shell.new(
      command: ["bash", "--noprofile", "--norc", "--login", "+o", "history"],
      env: ["PS1=\\[\\e[38;2;90;86;224m\\]> \\[\\e[0m\\]", "BASH_SILENCE_DEPRECATION_WARNING=1"]
    ),
    ZSH => Shell.new(
      command: ["zsh", "--histnostore", "--no-rcs"],
      env: ["PROMPT=%F{#5B56E0}> %F{reset_color}"]
    ),
    FISH => Shell.new(
      command: [
        "fish",
        "--login",
        "--no-config",
        "--private",
        "-C", "function fish_greeting; end",
        "-C", "function fish_prompt; set_color 5B56E0; echo -n \"> \"; set_color normal; end",
      ]
    ),
    POWERSHELL => Shell.new(
      command: [
        "powershell",
        "-NoLogo",
        "-NoExit",
        "-NoProfile",
        "-Command",
        "Set-PSReadLineOption -HistorySaveStyle SaveNothing; function prompt { Write-Host '>' -NoNewLine -ForegroundColor Blue; return ' ' }",
      ]
    ),
    PWSH => Shell.new(
      command: [
        "pwsh",
        "-Login",
        "-NoLogo",
        "-NoExit",
        "-NoProfile",
        "-Command",
        "Set-PSReadLineOption -HistorySaveStyle SaveNothing; Function prompt { Write-Host -ForegroundColor Blue -NoNewLine '>'; return ' ' }",
      ]
    ),
    CMDEXE => Shell.new(
      command: ["cmd.exe", "/k", "prompt=^> "]
    ),
    NUSHELL => Shell.new(
      command: ["nu", "--execute", "$env.PROMPT_COMMAND = {'\033[;38;2;91;86;224m>\033[m '}; $env.PROMPT_COMMAND_RIGHT = {''}"]
    ),
    OSH => Shell.new(
      command: ["osh", "--norc"],
      env: ["PS1=\\[\\e[38;2;90;86;224m\\]> \\[\\e[0m\\]"]
    ),
    XONSH => Shell.new(
      command: ["xonsh", "--no-rc", "-D", "PROMPT=\033[;38;2;91;86;224m>\033[m "]
    ),
  }

  # CommandFunc is a function that executes a command on a running
  # instance of vhs.
  alias CommandFunc = Proc(Parser::Command, VHS, Exception?)

  # CommandFuncs maps command types to their executable functions.
  @@command_funcs : Hash(Token::Type, CommandFunc)? = nil
  @@settings : Hash(String, CommandFunc)? = nil

  def self.command_funcs : Hash(Token::Type, CommandFunc)
    @@command_funcs ||= begin
      hash = {} of Token::Type => CommandFunc
      hash[Token::ILLEGAL] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_noop(cmd, v) }
      hash[Token::SLEEP] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_sleep(cmd, v) }
      hash[Token::TYPE] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_type(cmd, v) }
      hash[Token::OUTPUT] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_output(cmd, v) }
      hash[Token::SET] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set(cmd, v) }
      hash[Token::HIDE] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_hide(cmd, v) }
      hash[Token::SHOW] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_show(cmd, v) }
      hash[Token::REQUIRE] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_require(cmd, v) }
      hash[Token::ENV] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_env(cmd, v) }
      hash[Token::COPY] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_copy(cmd, v) }
      hash[Token::PASTE] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_paste(cmd, v) }
      hash[Token::WAIT] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_wait(cmd, v) }
      hash[Token::CTRL] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_ctrl(cmd, v) }
      hash[Token::ALT] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_alt(cmd, v) }
      hash[Token::SHIFT] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_shift(cmd, v) }
      # Key commands use execute_key with specific key
      # Key commands
      hash[Token::BACKSPACE] = execute_key("Backspace")
      hash[Token::DELETE] = execute_key("Delete")
      hash[Token::INSERT] = execute_key("Insert")
      hash[Token::DOWN] = execute_key("ArrowDown")
      hash[Token::ENTER] = execute_key("Enter")
      hash[Token::LEFT] = execute_key("ArrowLeft")
      hash[Token::RIGHT] = execute_key("ArrowRight")
      hash[Token::SPACE] = execute_key("Space")
      hash[Token::UP] = execute_key("ArrowUp")
      hash[Token::TAB] = execute_key("Tab")
      hash[Token::ESCAPE] = execute_key("Escape")
      hash[Token::PAGE_UP] = execute_key("PageUp")
      hash[Token::PAGE_DOWN] = execute_key("PageDown")
      hash
    end
  end

  # Settings maps the Set commands to their respective functions.
  def self.settings : Hash(String, CommandFunc)
    @@settings ||= begin
      hash = {} of String => CommandFunc
      hash["FontFamily"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_font_family(cmd, v) }
      hash["FontSize"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_font_size(cmd, v) }
      hash["Shell"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_shell(cmd, v) }
      hash["Theme"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_theme(cmd, v) }
      hash["TypingSpeed"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_typing_speed(cmd, v) }
      # TODO: Add more settings
      hash
    end
  end

  # ExecuteSet applies the settings on the running vhs specified by the
  # option and argument pass to the command.
  def self.execute_set(cmd : Parser::Command, v : VHS) : Exception?
    func = settings[cmd.options]?
    if func
      func.call(cmd, v)
    else
      Exception.new("invalid setting #{cmd.options}")
    end
  end

  # Execute executes a command on a running instance of vhs.
  def self.execute(cmd : Parser::Command, v : VHS) : Exception?
    func = command_funcs[cmd.type]?
    if func
      err = func.call(cmd, v)
      if err.nil? && v.recording? && !v.options.test.output.empty?
        err = v.save_output
      end
      err
    else
      Exception.new("no command function for #{cmd.type}")
    end
  end

  # ExecuteNoop is a no-op command that does nothing.
  # Generally, this is used for Unknown commands when dealing with
  # commands that are not recognized.
  def self.execute_noop(_cmd : Parser::Command, _v : VHS) : Exception?
    nil
  end

  # ExecuteSleep sleeps for the desired time specified through the argument of
  # the Sleep command.
  def self.execute_sleep(cmd : Parser::Command, _v : VHS) : Exception?
    # Parse duration (simple implementation for now)
    # Supports formats: "1s", "500ms", "0.5s"
    duration_str = cmd.args
    seconds = 0.0

    if duration_str.ends_with?("ms")
      ms = duration_str[0...-2].to_f? || 0.0
      seconds = ms / 1000.0
    elsif duration_str.ends_with?("s")
      s = duration_str[0...-1].to_f? || 0.0
      seconds = s
    else
      # Assume seconds
      seconds = duration_str.to_f? || 0.0
    end

    sleep(seconds.seconds) if seconds > 0

    nil
  end

  # ExecuteType types the argument string on the running instance of vhs.
  def self.execute_type(cmd : Parser::Command, v : VHS) : Exception?
    terminal = v.terminal
    return Exception.new("terminal not started") unless terminal

    text = cmd.args
    typing_speed = v.options.typing_speed

    if typing_speed > 0.milliseconds
      # Type character by character with delay
      text.each_char do |char|
        terminal.write(char.to_s)
        sleep(typing_speed)
      end
    else
      # Type all at once
      terminal.write(text)
    end

    nil
  end

  # ExecuteOutput applies the output on the vhs videos.
  def self.execute_output(cmd : Parser::Command, v : VHS) : Exception?
    case cmd.options
    when ".mp4"
      v.options.video.output.mp4 = cmd.args
    when ".test", ".ascii", ".txt"
      v.options.test.output = cmd.args
    when ".png"
      v.options.video.output.frames = cmd.args
    when ".webm"
      v.options.video.output.webm = cmd.args
    else
      v.options.video.output.gif = cmd.args
    end
    nil
  end

  # ExecuteHide is a CommandFunc that starts or stops the recording of the vhs.
  def self.execute_hide(_cmd : Parser::Command, v : VHS) : Exception?
    v.recording = false
    nil
  end

  # ExecuteShow is a CommandFunc that resumes the recording of the vhs.
  def self.execute_show(_cmd : Parser::Command, v : VHS) : Exception?
    v.recording = true
    nil
  end

  # ExecuteRequire is a CommandFunc that checks if all the binaries mentioned in the
  # Require command are present. If not, it exits with a non-zero error.
  def self.execute_require(cmd : Parser::Command, _v : VHS) : Exception?
    binary = cmd.args
    if Process.find_executable(binary).nil?
      return Exception.new("required binary '#{binary}' not found in PATH")
    end
    nil
  end

  # ExecuteEnv sets env with given key-value pair.
  def self.execute_env(cmd : Parser::Command, _v : VHS) : Exception?
    key = cmd.options
    value = cmd.args
    ENV[key] = value
    nil
  end

  # ExecuteCopy copies text to the clipboard.
  def self.execute_copy(cmd : Parser::Command, _v : VHS) : Exception?
    # TODO: Implement clipboard integration
    # For now, just no-op
    nil
  end

  # ExecutePaste pastes text from the clipboard.
  def self.execute_paste(_cmd : Parser::Command, _v : VHS) : Exception?
    # TODO: Implement clipboard integration
    # For now, just no-op
    nil
  end

  # ExecuteWait is a CommandFunc that waits for a regex match for the given amount of time.
  def self.execute_wait(cmd : Parser::Command, v : VHS) : Exception?
    args = cmd.args
    options = cmd.options

    # Parse timeout from options if present
    timeout = v.options.wait_timeout
    if !options.empty?
      # Parse duration string (similar to sleep)
      duration_str = options
      seconds = 0.0
      if duration_str.ends_with?("ms")
        ms = duration_str[0...-2].to_f? || 0.0
        seconds = ms / 1000.0
      elsif duration_str.ends_with?("s")
        s = duration_str[0...-1].to_f? || 0.0
        seconds = s
      else
        # Assume seconds
        seconds = duration_str.to_f? || 0.0
      end
      timeout = seconds.seconds
    end

    # Parse scope and regex from args
    parts = args.split(' ', 2)
    scope = "Line"
    pattern = v.options.wait_pattern
    if parts.size == 2
      scope = parts[0]
      pattern_str = parts[1]
      begin
        pattern = Regex.new(pattern_str)
      rescue ex
        return Exception.new("invalid regex: #{ex.message}")
      end
    elsif parts.size == 1 && !parts[0].empty?
      pattern_str = parts[0]
      begin
        pattern = Regex.new(pattern_str)
      rescue ex
        return Exception.new("invalid regex: #{ex.message}")
      end
    end

    # Validate scope
    unless {"Line", "Screen"}.includes?(scope)
      return Exception.new("invalid scope: #{scope}")
    end

    start_time = Time.monotonic
    tick = 10.milliseconds

    while (Time.monotonic - start_time) < timeout
      case scope
      when "Line"
        line = v.current_line
        if pattern.matches?(line)
          return nil
        end
      when "Screen"
        buffer = v.buffer
        text = buffer.join("\n")
        if pattern.matches?(text)
          return nil
        end
      end
      sleep tick
    end

    Exception.new("timeout waiting for pattern #{pattern}")
  end

  # ExecuteCtrl is a CommandFunc that presses the argument keys and/or modifiers
  # with the ctrl key held down on the running instance of vhs.
  def self.execute_ctrl(cmd : Parser::Command, _v : VHS) : Exception?
    # TODO: Implement ctrl key combination
    nil
  end

  # ExecuteAlt is a CommandFunc that presses the argument key with the alt key
  # held down on the running instance of vhs.
  def self.execute_alt(cmd : Parser::Command, _v : VHS) : Exception?
    # TODO: Implement alt key combination
    nil
  end

  # ExecuteShift is a CommandFunc that presses the argument key with the shift
  # key held down on the running instance of vhs.
  def self.execute_shift(cmd : Parser::Command, _v : VHS) : Exception?
    # TODO: Implement shift key combination
    nil
  end

  # ExecuteSetFontSize applies the font size on the vhs.
  def self.execute_set_font_size(cmd : Parser::Command, v : VHS) : Exception?
    font_size = cmd.args.to_i32?
    if font_size.nil? || font_size <= 0
      return Exception.new("invalid font size: #{cmd.args}")
    end
    opts = v.options.dup
    opts.font_size = font_size
    v.options = opts
    nil
  end

  # ExecuteSetFontFamily applies the font family on the vhs.
  def self.execute_set_font_family(cmd : Parser::Command, v : VHS) : Exception?
    opts = v.options.dup
    opts.font_family = cmd.args
    v.options = opts
    nil
  end

  # ExecuteSetShell applies the shell on the vhs.
  def self.execute_set_shell(cmd : Parser::Command, v : VHS) : Exception?
    shell_name = cmd.args
    shell = SHELLS[shell_name]?
    if shell.nil?
      return Exception.new("invalid shell: #{shell_name}")
    end
    opts = v.options.dup
    opts.shell = shell
    v.options = opts
    nil
  end

  # ExecuteSetTheme applies the theme on the vhs.
  def self.execute_set_theme(cmd : Parser::Command, v : VHS) : Exception?
    # TODO: Proper theme parsing and lookup
    # For now, just set default theme
    opts = v.options.dup
    opts.theme = DEFAULT_THEME
    v.options = opts
    nil
  end

  # ExecuteSetTypingSpeed applies the default typing speed on the vhs.
  def self.execute_set_typing_speed(cmd : Parser::Command, v : VHS) : Exception?
    duration_str = cmd.args
    seconds = 0.0

    if duration_str.ends_with?("ms")
      ms = duration_str[0...-2].to_f? || 0.0
      seconds = ms / 1000.0
    elsif duration_str.ends_with?("s")
      s = duration_str[0...-1].to_f? || 0.0
      seconds = s
    else
      # Assume milliseconds
      ms = duration_str.to_f? || 0.0
      seconds = ms / 1000.0
    end

    typing_speed = seconds.seconds
    opts = v.options.dup
    opts.typing_speed = typing_speed
    v.options = opts
    nil
  end

  # ExecuteKey is a higher-order function that returns a CommandFunc to execute
  # a key press for a given key. This is so that the logic for key pressing
  # (since they are repeatable and delayable) can be re-used.
  def self.execute_key(key : String) : CommandFunc
    ->(cmd : Parser::Command, v : VHS) : Exception? {
      terminal = v.terminal
      return Exception.new("terminal not started") unless terminal

      # Map key names to characters/sequences
      key_char = case key
                 when "Enter"
                   "\n"
                 when "Backspace"
                   "\b"
                 when "Delete"
                   "\u007f" # DEL character
                 when "Tab"
                   "\t"
                 when "Escape"
                   "\e"
                 when "Space"
                   " "
                 when "ArrowUp"
                   "\e[A"
                 when "ArrowDown"
                   "\e[B"
                 when "ArrowRight"
                   "\e[C"
                 when "ArrowLeft"
                   "\e[D"
                 when "PageUp"
                   "\e[5~"
                 when "PageDown"
                   "\e[6~"
                 else
                   # Default: send as-is (for keys like "a", "b", etc.)
                   key.downcase
                 end

      terminal.write(key_char)

      # Handle repeat count
      repeat = cmd.options.to_i? || 1
      if repeat > 1
        (repeat - 1).times do
          terminal.write(key_char)
        end
      end

      nil
    }
  end

  # Keymap is the map of runes to input.Keys.
  # It is used to convert a string to the correct set of input.Keys for go-rod.
  # TODO: Replace with term2 key representation.
  KEYMAP = {
    ' '      => "Space",
    '!'      => "Shift+1",
    '"'      => "Shift+Quote",
    '#'      => "Shift+3",
    '$'      => "Shift+4",
    '%'      => "Shift+5",
    '&'      => "Shift+7",
    '('      => "Shift+9",
    ')'      => "Shift+0",
    '*'      => "Shift+8",
    '+'      => "Shift+Equal",
    ','      => "Comma",
    '-'      => "Minus",
    '.'      => "Period",
    '/'      => "Slash",
    '0'      => "Digit0",
    '1'      => "Digit1",
    '2'      => "Digit2",
    '3'      => "Digit3",
    '4'      => "Digit4",
    '5'      => "Digit5",
    '6'      => "Digit6",
    '7'      => "Digit7",
    '8'      => "Digit8",
    '9'      => "Digit9",
    ':'      => "Shift+Semicolon",
    ';'      => "Semicolon",
    '<'      => "Shift+Comma",
    '='      => "Equal",
    '>'      => "Shift+Period",
    '?'      => "Shift+Slash",
    '@'      => "Shift+2",
    'A'      => "Shift+A",
    'B'      => "Shift+B",
    'C'      => "Shift+C",
    'D'      => "Shift+D",
    'E'      => "Shift+E",
    'F'      => "Shift+F",
    'G'      => "Shift+G",
    'H'      => "Shift+H",
    'I'      => "Shift+I",
    'J'      => "Shift+J",
    'K'      => "Shift+K",
    'L'      => "Shift+L",
    'M'      => "Shift+M",
    'N'      => "Shift+N",
    'O'      => "Shift+O",
    'P'      => "Shift+P",
    'Q'      => "Shift+Q",
    'R'      => "Shift+R",
    'S'      => "Shift+S",
    'T'      => "Shift+T",
    'U'      => "Shift+U",
    'V'      => "Shift+V",
    'W'      => "Shift+W",
    'X'      => "Shift+X",
    'Y'      => "Shift+Y",
    'Z'      => "Shift+Z",
    '['      => "BracketLeft",
    '\''     => "Quote",
    '\\'     => "Backslash",
    '\b'     => "Backspace",
    '\n'     => "Enter",
    '\r'     => "Enter",
    '\t'     => "Tab",
    0x1b.chr => "Escape",
    ']'      => "BracketRight",
    '^'      => "Shift+6",
    '_'      => "Shift+Minus",
    '`'      => "Backquote",
    'a'      => "A",
    'b'      => "B",
    'c'      => "C",
    'd'      => "D",
    'e'      => "E",
    'f'      => "F",
    'g'      => "G",
    'h'      => "H",
    'i'      => "I",
    'j'      => "J",
    'k'      => "K",
    'l'      => "L",
    'm'      => "M",
    'n'      => "N",
    'o'      => "O",
    'p'      => "P",
    'q'      => "Q",
    'r'      => "R",
    's'      => "S",
    't'      => "T",
    'u'      => "U",
    'v'      => "V",
    'w'      => "W",
    'x'      => "X",
    'y'      => "Y",
    'z'      => "Z",
    '{'      => "Shift+BracketLeft",
    '|'      => "Shift+Backslash",
    '}'      => "Shift+BracketRight",
    '~'      => "Shift+Backquote",
    '←'      => "ArrowLeft",
    '↑'      => "ArrowUp",
    '→'      => "ArrowRight",
    '↓'      => "ArrowDown",
  }

  # StyleOptions represents the ui options for video and screenshots.
  struct StyleOptions
    property width : Int32
    property height : Int32
    property padding : Int32
    property background_color : String
    property margin_fill : String
    property margin : Int32
    property window_bar : String
    property window_bar_size : Int32
    property window_bar_color : String
    property border_radius : Int32

    def initialize(
      *,
      @width : Int32 = 1200,
      @height : Int32 = 600,
      @padding : Int32 = 60,
      @background_color : String = "",
      @margin_fill : String = "",
      @margin : Int32 = 0,
      @window_bar : String = "",
      @window_bar_size : Int32 = 30,
      @window_bar_color : String = "",
      @border_radius : Int32 = 0,
    )
    end
  end

  # VideoOutputs is a mapping from file type to file path for all video outputs
  # of VHS.
  struct VideoOutputs
    property gif : String
    property webm : String
    property mp4 : String
    property frames : String

    def initialize(*, @gif = "", @webm = "", @mp4 = "", @frames = "")
    end
  end

  # VideoOptions is the set of options for converting frames to a GIF.
  struct VideoOptions
    property framerate : Int32
    property playback_speed : Float64
    property input : String
    property max_colors : Int32
    property output : VideoOutputs
    property starting_frame : Int32
    property style : StyleOptions

    def initialize(
      *,
      @framerate : Int32 = 50,
      @playback_speed : Float64 = 1.0,
      @input : String = "",
      @max_colors : Int32 = 256,
      @output = VideoOutputs.new,
      @starting_frame : Int32 = 1,
      @style = StyleOptions.new,
    )
    end
  end

  # ScreenshotOptions holds options for taking screenshots.
  struct ScreenshotOptions
    property path : String
    property style : StyleOptions

    def initialize(*, @path = "", @style = StyleOptions.new)
    end
  end

  # TestOptions holds options for testing.
  struct TestOptions
    property output : String

    def initialize(*, @output = "")
    end
  end

  # Shell is a type that contains a prompt and the command to set up the shell.
  struct Shell
    property command : Array(String)
    property env : Array(String)

    def initialize(*, @command = [] of String, @env = [] of String)
    end
  end

  # Theme is a terminal theme for xterm.js
  # It is used for marshalling between the xterm.js readable json format and a
  # valid go struct.
  # https://xtermjs.org/docs/api/terminal/interfaces/itheme/
  struct Theme
    property name : String
    property background : String
    property foreground : String
    property selection : String
    property cursor : String
    property cursor_accent : String
    property black : String
    property bright_black : String
    property red : String
    property bright_red : String
    property green : String
    property bright_green : String
    property yellow : String
    property bright_yellow : String
    property blue : String
    property bright_blue : String
    property magenta : String
    property bright_magenta : String
    property cyan : String
    property bright_cyan : String
    property white : String
    property bright_white : String

    def initialize(
      *,
      @name = "",
      @background = "",
      @foreground = "",
      @selection = "",
      @cursor = "",
      @cursor_accent = "",
      @black = "",
      @bright_black = "",
      @red = "",
      @bright_red = "",
      @green = "",
      @bright_green = "",
      @yellow = "",
      @bright_yellow = "",
      @blue = "",
      @bright_blue = "",
      @magenta = "",
      @bright_magenta = "",
      @cyan = "",
      @bright_cyan = "",
      @white = "",
      @bright_white = "",
    )
    end

    def to_json : String
      JSON.build do |json|
        json.object do
          json.field "name", name
          json.field "background", background
          json.field "foreground", foreground
          json.field "selection", selection
          json.field "cursor", cursor
          json.field "cursorAccent", cursor_accent
          json.field "black", black
          json.field "brightBlack", bright_black
          json.field "red", red
          json.field "brightRed", bright_red
          json.field "green", green
          json.field "brightGreen", bright_green
          json.field "yellow", yellow
          json.field "brightYellow", bright_yellow
          json.field "blue", blue
          json.field "brightBlue", bright_blue
          json.field "magenta", magenta
          json.field "brightMagenta", bright_magenta
          json.field "cyan", cyan
          json.field "brightCyan", bright_cyan
          json.field "white", white
          json.field "brightWhite", bright_white
        end
      end
    end

    def self.from_json(json : String) : Theme
      parsed = JSON.parse(json)
      Theme.new(
        name: parsed["name"]?.try(&.as_s) || "",
        background: parsed["background"]?.try(&.as_s) || "",
        foreground: parsed["foreground"]?.try(&.as_s) || "",
        selection: parsed["selection"]?.try(&.as_s) || "",
        cursor: parsed["cursor"]?.try(&.as_s) || "",
        cursor_accent: parsed["cursorAccent"]?.try(&.as_s) || "",
        black: parsed["black"]?.try(&.as_s) || "",
        bright_black: parsed["brightBlack"]?.try(&.as_s) || "",
        red: parsed["red"]?.try(&.as_s) || "",
        bright_red: parsed["brightRed"]?.try(&.as_s) || "",
        green: parsed["green"]?.try(&.as_s) || "",
        bright_green: parsed["brightGreen"]?.try(&.as_s) || "",
        yellow: parsed["yellow"]?.try(&.as_s) || "",
        bright_yellow: parsed["brightYellow"]?.try(&.as_s) || "",
        blue: parsed["blue"]?.try(&.as_s) || "",
        bright_blue: parsed["brightBlue"]?.try(&.as_s) || "",
        magenta: parsed["magenta"]?.try(&.as_s) || "",
        bright_magenta: parsed["brightMagenta"]?.try(&.as_s) || "",
        cyan: parsed["cyan"]?.try(&.as_s) || "",
        bright_cyan: parsed["brightCyan"]?.try(&.as_s) || "",
        white: parsed["white"]?.try(&.as_s) || "",
        bright_white: parsed["brightWhite"]?.try(&.as_s) || ""
      )
    end
  end

  # Options is the set of options for the setup.
  struct Options
    property shell : Shell
    property font_family : String
    property font_size : Int32
    property letter_spacing : Float64
    property line_height : Float64
    property typing_speed : Time::Span
    property theme : Theme
    property test : TestOptions
    property video : VideoOptions
    property loop_offset : Float64
    property wait_timeout : Time::Span
    property wait_pattern : Regex
    property? cursor_blink : Bool
    property screenshot : ScreenshotOptions
    property style : StyleOptions

    def initialize(
      *,
      @shell = Shell.new,
      @font_family = "",
      @font_size = 22,
      @letter_spacing = 1.0,
      @line_height = 1.0,
      @typing_speed = 50.milliseconds,
      @theme = Theme.new,
      @test = TestOptions.new,
      @video = VideoOptions.new,
      @loop_offset = 0.0,
      @wait_timeout = 15.seconds,
      @wait_pattern = /^$/,
      @cursor_blink = true,
      @screenshot = ScreenshotOptions.new,
      @style = StyleOptions.new,
    )
    end
  end

  # DefaultStyleOptions returns default Style config.
  def self.default_style_options : StyleOptions
    StyleOptions.new(
      width: DEFAULT_WIDTH,
      height: DEFAULT_HEIGHT,
      padding: DEFAULT_PADDING,
      margin_fill: DEFAULT_THEME.background,
      margin: 0,
      window_bar: "",
      window_bar_size: DEFAULT_WINDOW_BAR_SIZE,
      window_bar_color: DEFAULT_THEME.background,
      border_radius: 0,
      background_color: DEFAULT_THEME.background
    )
  end

  # DefaultVideoOptions returns the set of default options for converting frames
  # to a GIF, which are used if they are not overridden.
  def self.default_video_options : VideoOptions
    VideoOptions.new(
      framerate: DEFAULT_FRAMERATE,
      input: random_dir,
      max_colors: DEFAULT_MAX_COLORS,
      output: VideoOutputs.new,
      playback_speed: DEFAULT_PLAYBACK_SPEED,
      starting_frame: DEFAULT_STARTING_FRAME,
      style: default_style_options
    )
  end

  # DefaultVHSOptions returns the default set of options to use for the setup function.
  def self.default_vhs_options : Options
    style = default_style_options
    video = default_video_options
    video.style = style
    screenshot = ScreenshotOptions.new(path: video.input, style: style)

    Options.new(
      font_family: DEFAULT_FONT_FAMILY,
      font_size: DEFAULT_FONT_SIZE,
      letter_spacing: DEFAULT_LETTER_SPACING,
      line_height: DEFAULT_LINE_HEIGHT,
      typing_speed: DEFAULT_TYPING_SPEED,
      shell: SHELLS[DEFAULT_SHELL],
      theme: DEFAULT_THEME,
      cursor_blink: DEFAULT_CURSOR_BLINK,
      video: video,
      screenshot: screenshot,
      wait_timeout: DEFAULT_WAIT_TIMEOUT,
      wait_pattern: DEFAULT_WAIT_PATTERN,
      loop_offset: 0.0,
      test: TestOptions.new,
      style: style
    )
  end

  # random_dir returns a random temporary directory to be used for storing frames
  # from screenshots of the terminal.
  private def self.random_dir : String
    # Create a temporary directory in system temp
    tmpdir = ENV["TMPDIR"]? || "/tmp"
    prefix = "vhs-"
    loop do
      name = prefix + Random::Secure.hex(8)
      path = File.join(tmpdir, name)
      if !Dir.exists?(path)
        Dir.mkdir(path, 0o750)
        return path
      end
    end
  end

  private def self.double(n : Int32) : Int32
    n * 2
  end

  # Evaluate takes as input a tape string, an output writer, and an output file
  # and evaluates all the commands within the tape string and produces a GIF.
  def self.evaluate(tape : String, output : IO = STDOUT) : Array(Exception)
    l = Lexer.new(tape)
    p = Parser.new(l)

    cmds = p.parse
    errs = p.errors
    if !errs.empty? || cmds.empty?
      return [InvalidSyntaxError.new(errs)] of Exception
    end

    # Create VHS instance
    v = VHS.new

    # Apply default options
    v.options = default_vhs_options

    # Execute SET and ENV commands first (before starting recording)
    cmds.each do |cmd|
      if (cmd.type == Token::SET && cmd.options == "Shell") || cmd.type == Token::ENV
        err = execute(cmd, v)
        v.errors << err if err
      end
    end

    # Start VHS
    v.start

    # Execute remaining commands
    cmds.each do |cmd|
      unless (cmd.type == Token::SET && cmd.options == "Shell") || cmd.type == Token::ENV
        err = execute(cmd, v)
        v.errors << err if err
      end
    end

    # TODO: Render output
    v.errors
  end

  # TerminalEmulator provides a simple terminal emulator for running shell commands
  # and capturing output.
  class TerminalEmulator
    property process : Process
    property width : Int32
    property height : Int32
    property buffer : Array(Array(Char))
    property cursor_x : Int32
    property cursor_y : Int32
    property output_buffer : String::Builder
    property reader_fiber : Fiber?

    def initialize(shell_cmd : String, shell_args : Array(String) = [] of String, env : Hash(String, String)? = nil)
      @width = 80
      @height = 24
      @buffer = Array.new(@height) { Array.new(@width, ' ') }
      @cursor_x = 0
      @cursor_y = 0
      @output_buffer = String::Builder.new
      @reader_fiber = nil

      # Start shell process with PTY
      @process = Process.new(shell_cmd, shell_args, env: env, shell: false,
        input: Process::Redirect::Pipe,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe)

      # Set terminal size
      set_size(@width, @height)

      # Start background reader
      start_reader
    end

    # Write text to the terminal (simulates typing)
    def write(text : String) : Nil
      @process.input << text
      @process.input.flush
    end

    # Read output from terminal
    def read(timeout_ms : Int32 = 100) : String
      output = Bytes.new(4096)
      bytes_read = 0

      # Try to read available output
      begin
        bytes_read = @process.output.read_nonblock(output)
      rescue IO::Timeout
        # No data available
      end

      String.new(output[0, bytes_read])
    end

    # Set terminal size
    def set_size(width : Int32, height : Int32) : Nil
      @width = width
      @height = height
      @buffer = Array.new(@height) { Array.new(@width, ' ') }

      # Send resize signal to process
      # Note: This is a simplified implementation
      # In a real terminal emulator, we'd send SIGWINCH
    end

    # Start background reader to capture output
    private def start_reader : Nil
      @reader_fiber = spawn do
        output = Bytes.new(4096)
        loop do
          begin
            bytes_read = @process.output.read(output)
            break if bytes_read == 0 # EOF

            chunk = String.new(output[0, bytes_read])
            @output_buffer << chunk
            # Also update buffer with simple handling
            update_buffer(chunk)
          rescue IO::Error
            # Process likely ended
            break
          end
        end
      end
    end

    # Update buffer with output (simple implementation)
    private def update_buffer(chunk : String) : Nil
      # Simple handling: just append characters to current position
      # This doesn't handle ANSI escapes properly
      chunk.each_char do |char|
        next if char == '\r' # Ignore carriage return
        if char == '\n'
          @cursor_x = 0
          @cursor_y += 1
          if @cursor_y >= @height
            # Scroll
            @buffer.shift
            @buffer << Array.new(@width, ' ')
            @cursor_y = @height - 1
          end
        elsif char == '\b' # Backspace
          @cursor_x -= 1 if @cursor_x > 0
          @buffer[@cursor_y][@cursor_x] = ' ' if @cursor_x >= 0 && @cursor_x < @width
        elsif char.control?
          # Ignore other control characters for now
        else
          if @cursor_x < @width && @cursor_y < @height
            @buffer[@cursor_y][@cursor_x] = char
            @cursor_x += 1
          end
        end
      end
    end

    # Get terminal contents as text
    def contents : String
      @output_buffer.to_s
    end

    # Get terminal screen as lines
    def screen_lines : Array(String)
      lines = [] of String
      @buffer.each do |row|
        line = String.build do |str|
          row.each { |char| str << char }
        end
        # Trim trailing spaces
        lines << line.rstrip
      end
      lines
    end

    # Close the terminal
    def close : Nil
      @reader_fiber.try &.terminate if @reader_fiber
      @process.terminate
    end
  end

  # VHS is the object that controls the setup.
  class VHS
    property options : Options
    property errors : Array(Exception)
    property? started : Bool
    property? recording : Bool
    property total_frames : Int32
    property terminal : TerminalEmulator?
    property mutex : Mutex

    def initialize
      @options = Options.new
      @errors = [] of Exception
      @started = false
      @recording = true
      @total_frames = 0
      @terminal = nil
      @mutex = Mutex.new
    end

    # Start starts ttyd, browser and everything else needed to create the gif.
    def start : Nil
      @mutex.lock
      begin
        if started?
          @errors << Exception.new("vhs is already started")
          return
        end

        # Create terminal emulator with shell
        shell_cmd = @options.shell.command[0]? || ""
        shell_args = @options.shell.command[1..]
        env_array = @options.shell.env
        env_hash = {} of String => String
        env_array.each do |entry|
          if entry.includes?('=')
            key, val = entry.split('=', 2)
            env_hash[key] = val
          end
        end
        env = env_hash.empty? ? nil : env_hash

        @terminal = TerminalEmulator.new(shell_cmd, shell_args, env)

        @started = true
      ensure
        @mutex.unlock
      end
    end

    # Buffer returns the current terminal buffer lines.
    def buffer : Array(String)
      term = @terminal
      return [] of String unless term
      term.screen_lines
    end

    # CurrentLine returns the current line from the buffer.
    def current_line : String
      # TODO: implement cursor position tracking
      lines = buffer
      return "" if lines.empty?
      lines.last
    end

    # SaveOutput saves the current buffer to the test output file.
    def save_output : Exception?
      output_path = @options.test.output
      return nil if output_path.empty?

      # Create directory if needed
      dir = File.dirname(output_path)
      unless Dir.exists?(dir)
        Dir.mkdir_p(dir)
      end

      lines = buffer
      separator = "────────────────────────────────────────────────────────────────────────────────"

      begin
        File.open(output_path, "a") do |file|
          lines.each do |line|
            file.puts(line)
          end
          file.puts(separator)
        end
      rescue ex
        return ex
      end

      nil
    end
  end
end
