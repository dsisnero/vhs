require "ultraviolet"
require "process"
require "random/secure"
require "./png_renderer"

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

  # Path to themes.json file (relative to project root)
  THEMES_JSON_PATH = File.expand_path("../../vendor/vhs/themes.json", __DIR__)

  # Cached themes loaded from themes.json
  @@themes : Array(Theme)? = nil

  # Load themes from themes.json file
  private def self.load_themes : Array(Theme)
    @@themes ||= begin
      content = File.read(THEMES_JSON_PATH)
      Array(Theme).from_json(content)
    rescue ex : File::NotFoundError
      [] of Theme
    end
  end

  # Returns sorted theme names (public for testing)
  def self.sorted_theme_names : Array(String)
    load_themes.map(&.name).sort_by!(&.downcase)
  end

  # Levenshtein distance between two strings
  private def self.levenshtein_distance(a : String, b : String) : Int32
    n = a.size
    m = b.size
    return m if n == 0
    return n if m == 0

    # Create two rows
    row0 = Array.new(m + 1, 0)
    row1 = Array.new(m + 1, 0)

    (0..m).each { |j| row0[j] = j }

    (1..n).each do |i|
      row1[0] = i
      (1..m).each do |j|
        cost = a[i - 1] == b[j - 1] ? 0 : 1
        row1[j] = {row1[j - 1] + 1, row0[j] + 1, row0[j - 1] + cost}.min
      end
      row0, row1 = row1, row0
    end

    row0[m]
  end

  # Find theme by name, returns theme or raises ThemeNotFoundError
  private def self.find_theme(name : String) : Theme
    themes = load_themes
    # Exact match
    themes.each do |theme|
      return theme if theme.name == name
    end

    # Not found, compute suggestions
    suggestions = [] of String
    lname = name.downcase
    themes.each do |theme|
      ltheme = theme.name.downcase
      # Levenshtein distance <= 2
      distance = levenshtein_distance(lname, ltheme)
      suggest_by_distance = distance <= 2
      suggest_by_prefix = lname.starts_with?(ltheme)
      if suggest_by_distance || suggest_by_prefix
        suggestions << theme.name
      end
    end

    raise ThemeNotFoundError.new(name, suggestions)
  end

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

  # Simple clipboard storage for Copy/Paste commands
  @@clipboard : String = ""

  def self.clipboard : String
    @@clipboard
  end

  def self.clipboard=(text : String)
    @@clipboard = text
  end

  # InvalidSyntaxError is returned when the parser encounters one or more errors.
  class InvalidSyntaxError < Exception
    getter errors : Array(Parser::ParserError)

    def initialize(@errors : Array(Parser::ParserError))
    end

    def message : String
      "parser: #{errors.size} error(s)"
    end
  end

  # ThemeNotFoundError is returned when a requested theme is not found.
  class ThemeNotFoundError < Exception
    getter theme : String
    getter suggestions : Array(String)

    def initialize(@theme : String, @suggestions : Array(String) = [] of String)
    end

    def message : String
      if suggestions.empty?
        "invalid `Set Theme #{theme.inspect}`: theme does not exist"
      else
        "invalid `Set Theme #{theme.inspect}`: did you mean #{suggestions.map(&.inspect).join(", ")}"
      end
    end
  end

  # InvalidThemeError is returned when a theme JSON is invalid.
  class InvalidThemeError < Exception
    getter theme : String

    def initialize(@theme : String, cause : Exception? = nil)
      super("invalid `Set Theme #{theme.inspect}`: #{cause.try(&.message) || "invalid JSON"}", cause)
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
      hash[Token::SCREENSHOT] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_screenshot(cmd, v) }
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
      hash["Framerate"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_framerate(cmd, v) }
      hash["Height"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_height(cmd, v) }
      hash["LetterSpacing"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_letter_spacing(cmd, v) }
      hash["LineHeight"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_line_height(cmd, v) }
      hash["PlaybackSpeed"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_playback_speed(cmd, v) }
      hash["Padding"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_padding(cmd, v) }
      hash["Theme"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_theme(cmd, v) }
      hash["TypingSpeed"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_typing_speed(cmd, v) }
      hash["Width"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_width(cmd, v) }
      hash["Shell"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_shell(cmd, v) }
      hash["LoopOffset"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_loop_offset(cmd, v) }
      hash["MarginFill"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_margin_fill(cmd, v) }
      hash["Margin"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_margin(cmd, v) }
      hash["WindowBar"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_window_bar(cmd, v) }
      hash["WindowBarSize"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_window_bar_size(cmd, v) }
      hash["BorderRadius"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_border_radius(cmd, v) }
      hash["WaitPattern"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_wait_pattern(cmd, v) }
      hash["WaitTimeout"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_wait_timeout(cmd, v) }
      hash["CursorBlink"] = ->(cmd : Parser::Command, v : VHS) : Exception? { execute_set_cursor_blink(cmd, v) }
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
    text = cmd.args
    self.clipboard = text
    nil
  end

  # ExecutePaste pastes text from the clipboard.
  def self.execute_paste(_cmd : Parser::Command, v : VHS) : Exception?
    terminal = v.terminal
    return Exception.new("terminal not started") unless terminal

    text = self.clipboard
    terminal.write(text) unless text.empty?
    nil
  end

  # ExecuteScreenshot is a CommandFunc that indicates a new screenshot must be taken.
  def self.execute_screenshot(cmd : Parser::Command, v : VHS) : Exception?
    path = cmd.args
    if path.empty?
      return Exception.new("Screenshot path is required")
    end

    term = v.terminal
    if term.nil?
      return Exception.new("Terminal not started")
    end

    buffer = term.buffer
    if buffer.empty?
      # Empty buffer, still create PNG with background
      buffer = Array.new(term.height) { Array.new(term.width, ' ') }
    end

    # Get font settings from options
    opts = v.options
    foreground = opts.theme.foreground
    background = opts.theme.background

    # Render PNG
    ::VHS::PNGRenderer.render(buffer, path,
      font_family: opts.font_family,
      font_size: opts.font_size,
      letter_spacing: opts.letter_spacing,
      line_height: opts.line_height,
      foreground: foreground,
      background: background
    )

    # Increment frame count (for recording loop)
    v.total_frames += 1
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

    start_time = Time.instant
    tick = 10.milliseconds

    while (Time.instant - start_time) < timeout
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
  def self.execute_ctrl(cmd : Parser::Command, v : VHS) : Exception?
    terminal = v.terminal
    return Exception.new("terminal not started") unless terminal

    keys = cmd.args.split(' ')

    # For terminal, we send control characters
    # Ctrl+letter = ASCII 1-26 (A=1, B=2, ...)
    # Special cases: Ctrl+[ = ESC (\x1b), Ctrl+\ = FS (\x1c), etc.
    keys.each do |key|
      case key.downcase
      when "c"
        terminal.write("\x03") # Ctrl+C (ETX)
      when "d"
        terminal.write("\x04") # Ctrl+D (EOT)
      when "z"
        terminal.write("\x1a") # Ctrl+Z (SUB)
      when "["
        terminal.write("\x1b") # Ctrl+[ = ESC
      when "\\"
        terminal.write("\x1c") # Ctrl+\ = FS
      when "]"
        terminal.write("\x1d") # Ctrl+] = GS
      when "^"
        terminal.write("\x1e") # Ctrl+^ = RS
      when "_"
        terminal.write("\x1f") # Ctrl+_ = US
      when "?"
        terminal.write("\x7f") # Ctrl+? = DEL
      when "shift"
        # Ctrl+Shift - just ignore shift for now
        next
      when "alt"
        # Ctrl+Alt - just ignore alt for now
        next
      when "enter"
        # Ctrl+Enter - send CR (but terminal might interpret differently)
        terminal.write("\r")
      when "space"
        # Ctrl+Space = NUL
        terminal.write("\x00")
      when "backspace"
        # Ctrl+Backspace = DEL
        terminal.write("\x7f")
      else
        # Check if single letter A-Z
        if key.size == 1 && key.matches?(/^[A-Za-z]$/)
          char_code = key.downcase[0].ord - 'a'.ord + 1
          terminal.write(char_code.chr.to_s)
        else
          # Unknown key, skip
          next
        end
      end
    end

    nil
  end

  # ExecuteAlt is a CommandFunc that presses the argument key with the alt key
  # held down on the running instance of vhs.
  def self.execute_alt(cmd : Parser::Command, v : VHS) : Exception?
    terminal = v.terminal
    return Exception.new("terminal not started") unless terminal

    key = cmd.args

    # In terminal, Alt+key is typically ESC followed by the key
    # Alt+A = \x1ba, Alt+Enter = \x1b\r, etc.
    case key.downcase
    when "enter"
      terminal.write("\x1b\r")
    when "tab"
      terminal.write("\x1b\t")
    when "space"
      terminal.write("\x1b ")
    when "backspace"
      terminal.write("\x1b\b")
    else
      # Check if single character
      if key.size == 1
        terminal.write("\x1b#{key}")
      else
        # Multi-character, send Alt for each?
        key.each_char do |char|
          terminal.write("\x1b#{char}")
        end
      end
    end

    nil
  end

  # ExecuteShift is a CommandFunc that presses the argument key with the shift
  # key held down on the running instance of vhs.
  def self.execute_shift(cmd : Parser::Command, v : VHS) : Exception?
    terminal = v.terminal
    return Exception.new("terminal not started") unless terminal

    key = cmd.args

    # For terminal, Shift just produces the shifted character
    # Shift+A = 'A', Shift+1 = '!', etc.
    # We need to map key names to shifted characters
    case key.downcase
    when "enter"
      # Shift+Enter - just send Enter
      terminal.write("\r")
    when "tab"
      # Shift+Tab is actually backtab: \x1b[Z
      terminal.write("\x1b[Z")
    when "space"
      terminal.write(" ")
    when "backspace"
      terminal.write("\b")
    else
      # Single character - check if we need to shift it
      if key.size == 1
        char = key[0]
        # Simple mapping for common shifted characters
        shifted = case char
                  when '1'  then '!'
                  when '2'  then '@'
                  when '3'  then '#'
                  when '4'  then '$'
                  when '5'  then '%'
                  when '6'  then '^'
                  when '7'  then '&'
                  when '8'  then '*'
                  when '9'  then '('
                  when '0'  then ')'
                  when '-'  then '_'
                  when '='  then '+'
                  when '['  then '{'
                  when ']'  then '}'
                  when '\\' then '|'
                  when ';'  then ':'
                  when '\'' then '"'
                  when ','  then '<'
                  when '.'  then '>'
                  when '/'  then '?'
                  when '`'  then '~'
                  else
                    char.upcase
                  end
        terminal.write(shifted.to_s)
      else
        # Multi-character, capitalize each?
        terminal.write(key.upcase)
      end
    end

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
    theme = get_theme(cmd.args)
    opts = v.options.dup
    opts.theme = theme
    v.options = opts
    nil
  rescue ex : ThemeNotFoundError | InvalidThemeError
    ex
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

  # ExecuteSetFramerate applies the framerate on the vhs.
  def self.execute_set_framerate(cmd : Parser::Command, v : VHS) : Exception?
    framerate = cmd.args.to_i32?
    if framerate.nil? || framerate <= 0
      return Exception.new("invalid framerate: #{cmd.args}")
    end
    opts = v.options.dup
    video = opts.video.dup
    video.framerate = framerate
    opts.video = video
    v.options = opts
    nil
  end

  # ExecuteSetHeight applies the height on the vhs.
  def self.execute_set_height(cmd : Parser::Command, v : VHS) : Exception?
    height = cmd.args.to_i32?
    if height.nil? || height <= 0
      return Exception.new("invalid height: #{cmd.args}")
    end
    opts = v.options.dup
    style = opts.style.dup
    style.height = height
    opts.style = style
    v.options = opts
    nil
  end

  # ExecuteSetLetterSpacing applies the letter spacing on the vhs.
  def self.execute_set_letter_spacing(cmd : Parser::Command, v : VHS) : Exception?
    letter_spacing = cmd.args.to_f64?
    if letter_spacing.nil? || letter_spacing <= 0.0
      return Exception.new("invalid letter spacing: #{cmd.args}")
    end
    opts = v.options.dup
    opts.letter_spacing = letter_spacing
    v.options = opts
    nil
  end

  # ExecuteSetLineHeight applies the line height on the vhs.
  def self.execute_set_line_height(cmd : Parser::Command, v : VHS) : Exception?
    line_height = cmd.args.to_f64?
    if line_height.nil? || line_height <= 0.0
      return Exception.new("invalid line height: #{cmd.args}")
    end
    opts = v.options.dup
    opts.line_height = line_height
    v.options = opts
    nil
  end

  # ExecuteSetPlaybackSpeed applies the playback speed on the vhs.
  def self.execute_set_playback_speed(cmd : Parser::Command, v : VHS) : Exception?
    playback_speed = cmd.args.to_f64?
    if playback_speed.nil? || playback_speed <= 0.0
      return Exception.new("invalid playback speed: #{cmd.args}")
    end
    opts = v.options.dup
    video = opts.video.dup
    video.playback_speed = playback_speed
    opts.video = video
    v.options = opts
    nil
  end

  # ExecuteSetPadding applies the padding on the vhs.
  def self.execute_set_padding(cmd : Parser::Command, v : VHS) : Exception?
    padding = cmd.args.to_i32?
    if padding.nil? || padding < 0
      return Exception.new("invalid padding: #{cmd.args}")
    end
    opts = v.options.dup
    style = opts.style.dup
    style.padding = padding
    opts.style = style
    v.options = opts
    nil
  end

  # ExecuteSetWidth applies the width on the vhs.
  def self.execute_set_width(cmd : Parser::Command, v : VHS) : Exception?
    width = cmd.args.to_i32?
    if width.nil? || width <= 0
      return Exception.new("invalid width: #{cmd.args}")
    end
    opts = v.options.dup
    style = opts.style.dup
    style.width = width
    opts.style = style
    v.options = opts
    nil
  end

  # ExecuteLoopOffset applies the loop offset on the vhs.
  def self.execute_loop_offset(cmd : Parser::Command, v : VHS) : Exception?
    loop_offset = cmd.args.to_f64?
    if loop_offset.nil? || loop_offset < 0.0
      return Exception.new("invalid loop offset: #{cmd.args}")
    end
    opts = v.options.dup
    opts.loop_offset = loop_offset
    v.options = opts
    nil
  end

  # ExecuteSetMarginFill applies the margin fill on the vhs.
  def self.execute_set_margin_fill(cmd : Parser::Command, v : VHS) : Exception?
    opts = v.options.dup
    style = opts.style.dup
    style.margin_fill = cmd.args
    opts.style = style
    v.options = opts
    nil
  end

  # ExecuteSetMargin applies the margin on the vhs.
  def self.execute_set_margin(cmd : Parser::Command, v : VHS) : Exception?
    margin = cmd.args.to_i32?
    if margin.nil? || margin < 0
      return Exception.new("invalid margin: #{cmd.args}")
    end
    opts = v.options.dup
    style = opts.style.dup
    style.margin = margin
    opts.style = style
    v.options = opts
    nil
  end

  # ExecuteSetWindowBar applies the window bar on the vhs.
  def self.execute_set_window_bar(cmd : Parser::Command, v : VHS) : Exception?
    opts = v.options.dup
    style = opts.style.dup
    style.window_bar = cmd.args
    opts.style = style
    v.options = opts
    nil
  end

  # ExecuteSetWindowBarSize applies the window bar size on the vhs.
  def self.execute_set_window_bar_size(cmd : Parser::Command, v : VHS) : Exception?
    window_bar_size = cmd.args.to_i32?
    if window_bar_size.nil? || window_bar_size < 0
      return Exception.new("invalid window bar size: #{cmd.args}")
    end
    opts = v.options.dup
    style = opts.style.dup
    style.window_bar_size = window_bar_size
    opts.style = style
    v.options = opts
    nil
  end

  # ExecuteSetBorderRadius applies the border radius on the vhs.
  def self.execute_set_border_radius(cmd : Parser::Command, v : VHS) : Exception?
    border_radius = cmd.args.to_i32?
    if border_radius.nil? || border_radius < 0
      return Exception.new("invalid border radius: #{cmd.args}")
    end
    opts = v.options.dup
    style = opts.style.dup
    style.border_radius = border_radius
    opts.style = style
    v.options = opts
    nil
  end

  # ExecuteSetWaitPattern applies the wait pattern on the vhs.
  def self.execute_set_wait_pattern(cmd : Parser::Command, v : VHS) : Exception?
    begin
      pattern = Regex.new(cmd.args)
    rescue ex
      return Exception.new("invalid regex pattern: #{cmd.args}")
    end
    opts = v.options.dup
    opts.wait_pattern = pattern
    v.options = opts
    nil
  end

  # ExecuteSetWaitTimeout applies the wait timeout on the vhs.
  def self.execute_set_wait_timeout(cmd : Parser::Command, v : VHS) : Exception?
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

    if seconds <= 0.0
      return Exception.new("invalid wait timeout: #{cmd.args}")
    end

    wait_timeout = seconds.seconds
    opts = v.options.dup
    opts.wait_timeout = wait_timeout
    v.options = opts
    nil
  end

  # ExecuteSetCursorBlink applies the cursor blink on the vhs.
  def self.execute_set_cursor_blink(cmd : Parser::Command, v : VHS) : Exception?
    value = cmd.args.downcase
    cursor_blink = case value
                   when "true", "on", "yes", "1"
                     true
                   when "false", "off", "no", "0"
                     false
                   else
                     return Exception.new("invalid cursor blink value: #{cmd.args}")
                   end
    opts = v.options.dup
    opts.cursor_blink = cursor_blink
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
                 when "Insert"
                   "\e[2~"
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
                 when "Home"
                   "\e[1~"
                 when "End"
                   "\e[4~"
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
    property frame_capture : Bool
    property next_screenshot_path : String
    property screenshots : Hash(String, Int32)
    property input : String
    property style : StyleOptions

    def initialize(
      *,
      @input = "",
      @style = StyleOptions.new,
      @frame_capture = false,
      @next_screenshot_path = "",
      @screenshots = {} of String => Int32,
    )
    end

    # make_screenshot stores in screenshots map the target frame of the screenshot.
    # After storing frame it disables frame capture.
    def make_screenshot(frame : Int32)
      @screenshots[@next_screenshot_path] = frame
      @frame_capture = false
      @next_screenshot_path = ""
    end

    # enable_frame_capture prepares capture of next frame by given path.
    def enable_frame_capture(path : String)
      @frame_capture = true
      @next_screenshot_path = path
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
    include JSON::Serializable

    property name : String = ""
    @[JSON::Field(key: "background")]
    property background : String = ""
    @[JSON::Field(key: "foreground")]
    property foreground : String = ""
    @[JSON::Field(key: "selection")]
    property selection : String = ""
    @[JSON::Field(key: "cursor")]
    property cursor : String = ""
    @[JSON::Field(key: "cursorAccent")]
    property cursor_accent : String = ""
    @[JSON::Field(key: "black")]
    property black : String = ""
    @[JSON::Field(key: "brightBlack")]
    property bright_black : String = ""
    @[JSON::Field(key: "red")]
    property red : String = ""
    @[JSON::Field(key: "brightRed")]
    property bright_red : String = ""
    @[JSON::Field(key: "green")]
    property green : String = ""
    @[JSON::Field(key: "brightGreen")]
    property bright_green : String = ""
    @[JSON::Field(key: "yellow")]
    property yellow : String = ""
    @[JSON::Field(key: "brightYellow")]
    property bright_yellow : String = ""
    @[JSON::Field(key: "blue")]
    property blue : String = ""
    @[JSON::Field(key: "brightBlue")]
    property bright_blue : String = ""
    @[JSON::Field(key: "magenta")]
    property magenta : String = ""
    @[JSON::Field(key: "brightMagenta")]
    property bright_magenta : String = ""
    @[JSON::Field(key: "cyan")]
    property cyan : String = ""
    @[JSON::Field(key: "brightCyan")]
    property bright_cyan : String = ""
    @[JSON::Field(key: "white")]
    property white : String = ""
    @[JSON::Field(key: "brightWhite")]
    property bright_white : String = ""

    # Ignore extra fields like "meta"
    @[JSON::Field(ignore: true)]
    property meta : JSON::Any? = nil

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
      @meta = nil,
    )
    end
  end

  # get_theme returns a Theme for the given string.
  # If the string is empty or whitespace, returns DEFAULT_THEME.
  # If the string starts with '{', it is parsed as JSON.
  # Otherwise, it is treated as a theme name and looked up in themes.json.
  def self.get_theme(s : String) : Theme
    s = s.strip
    if s.empty?
      return DEFAULT_THEME
    end

    case s[0]
    when '{'
      # JSON theme
      begin
        Theme.from_json(s)
      rescue ex : JSON::ParseException
        raise InvalidThemeError.new(s, ex)
      end
    else
      # Named theme
      find_theme(s)
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
    screenshot = ScreenshotOptions.new(input: video.input, style: style)

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
    property frame_capture_fiber : Fiber?
    property stop_frame_capture : Channel(Nil)?

    def initialize
      @options = Options.new
      @errors = [] of Exception
      @started = false
      @recording = true
      @total_frames = 0
      @terminal = nil
      @mutex = Mutex.new
      @frame_capture_fiber = nil
      @stop_frame_capture = nil
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

        # Ensure video input directory exists
        ensure_input_dir

        # Start frame capture loop
        start_frame_capture

        @started = true
      ensure
        @mutex.unlock
      end
    end

    # Ensure video input directory exists
    private def ensure_input_dir : Nil
      input_dir = @options.video.input
      return if input_dir.empty?
      Dir.mkdir_p(input_dir)
    end

    # Start frame capture loop
    private def start_frame_capture : Nil
      return unless @recording
      return if @frame_capture_fiber

      framerate = @options.video.framerate
      frame_interval = 1.0 / framerate
      stop_channel = Channel(Nil).new
      @stop_frame_capture = stop_channel

      @frame_capture_fiber = spawn do
        loop do
          sleep frame_interval
          select
          when stop_channel.receive
            break
          else
            # Capture frame
            capture_frame
          end
        end
      end
    end

    # Stop frame capture loop
    private def stop_frame_capture : Nil
      if stop = @stop_frame_capture
        stop.close
        @stop_frame_capture = nil
      end
      if fiber = @frame_capture_fiber
        fiber.terminate
        @frame_capture_fiber = nil
      end
    end

    # Capture a single frame and save as PNG
    private def capture_frame : Nil
      term = @terminal
      return unless term
      return unless @recording

      buffer = term.buffer
      return if buffer.empty?

      # Generate frame filename
      frame_num = @total_frames + 1
      filename = sprintf("frame_%04d.png", frame_num)
      path = File.join(@options.video.input, filename)

      # Get font settings from options
      opts = @options
      foreground = opts.theme.foreground
      background = opts.theme.background

      # Render PNG
      ::VHS::PNGRenderer.render(buffer, path,
        font_family: opts.font_family,
        font_size: opts.font_size,
        letter_spacing: opts.letter_spacing,
        line_height: opts.line_height,
        foreground: foreground,
        background: background
      )

      @total_frames += 1
    end

    # Close stops recording and cleans up resources
    def close : Nil
      stop_frame_capture
      term = @terminal
      term.try(&.close) if term
      @started = false
      @recording = false
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
