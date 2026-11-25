require "rod"
require "process"
require "random/secure"
require "./assets"
require "./ffmpeg_renderer"

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

  # Cached themes decoded from the baked themes.json
  @@themes : Array(Theme)? = nil

  # load_themes decodes the embedded themes.json, upstream's `//go:embed` data.
  private def self.load_themes : Array(Theme)
    @@themes ||= Array(Theme).from_json(Assets.get("themes.json").read)
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
  SEPARATOR               = "\u2500" * 80

  # WaitTick is the polling interval used by ExecuteWait, like upstream's
  # WaitTick constant.
  WAIT_TICK = 10.milliseconds

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
    return Exception.new("no command function for #{cmd.type}") if func.nil?

    # Upstream wraps both failure sources: the command itself and the test
    # output flush that follows a successful command while recording.
    if err = func.call(cmd, v)
      # Keep the original as the cause, like Go's %w wrapping.
      return Exception.new("failed to execute command: #{err.message}", cause: err)
    end

    if v.recording? && !v.options.test.output.empty?
      if err = v.save_output
        return Exception.new("failed to save output: #{err.message}", cause: err)
      end
    end

    nil
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
    duration = Vhs.parse_duration(cmd.args)
    if duration.nil?
      return Exception.new("failed to parse duration: #{cmd.args}")
    end

    sleep(duration) if duration > 0.seconds

    nil
  end

  # ExecuteType types the argument string on the running instance of vhs.
  def self.execute_type(cmd : Parser::Command, v : VHS) : Exception?
    page = v.page
    return Exception.new("vhs is not started") if page.nil?

    typing_speed = v.options.typing_speed
    unless cmd.options.empty?
      parsed = Vhs.parse_duration(cmd.options)
      if parsed.nil?
        return Exception.new("failed to parse typing speed: #{cmd.options}")
      end
      typing_speed = parsed
    end

    cmd.args.each_char do |char|
      if key = Keys.key_for(char)
        page.keyboard.type(key)
      else
        page.element("textarea").input(char.to_s)
        page.wait_idle(2.seconds) rescue nil
      end
      sleep(typing_speed) if typing_speed > 0.milliseconds
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
    page = v.page
    return Exception.new("vhs is not started") if page.nil?

    type_text(page, self.clipboard)
    nil
  end

  # ExecuteScreenshot is a CommandFunc that indicates a new screenshot must be taken.
  def self.execute_screenshot(cmd : Parser::Command, v : VHS) : Exception?
    path = cmd.args
    if path.empty?
      return Exception.new("Screenshot path is required")
    end

    # Upstream ExecuteScreenshot only arms the next frame capture; the styled
    # PNG is produced later by the ffmpeg screenshot pass.
    v.options.screenshot.enable_frame_capture(path)
    nil
  end

  # ExecuteWait is a CommandFunc that waits for a regex match for the given amount of time.
  def self.execute_wait(cmd : Parser::Command, v : VHS) : Exception?
    timeout = v.options.wait_timeout
    if !cmd.options.empty?
      parsed = Vhs.parse_duration(cmd.options)
      if parsed.nil?
        return Exception.new("failed to parse duration: #{cmd.options}")
      end
      timeout = parsed
    end

    scope = "Line"
    pattern = v.options.wait_pattern
    args = cmd.args.strip
    unless args.empty?
      parts = args.split(' ', 2)
      first = parts[0]
      if first == "Line" || first == "Screen"
        scope = first
        if parts.size == 2
          begin
            pattern = Regex.new(parts[1])
          rescue ex
            return Exception.new("invalid regex: #{ex.message}")
          end
        end
      else
        begin
          pattern = Regex.new(first)
        rescue ex
          return Exception.new("invalid regex: #{ex.message}")
        end
      end
    end

    unless {"Line", "Screen"}.includes?(scope)
      return Exception.new("invalid scope: #{scope}")
    end

    if pattern.nil?
      return Exception.new("no wait pattern set")
    end

    start_time = Time.instant
    last_value = ""

    while (Time.instant - start_time) < timeout
      case scope
      when "Line"
        last_value = v.current_line
        if pattern.matches?(last_value)
          return nil
        end
      when "Screen"
        last_value = v.buffer.join("\n")
        if pattern.matches?(last_value)
          return nil
        end
      end
      sleep WAIT_TICK
    end

    Exception.new("timeout waiting for #{cmd.args.inspect} to match #{pattern.inspect}; last value was: #{last_value}")
  end

  # ExecuteCtrl is a CommandFunc that presses the argument keys and/or modifiers
  # with the ctrl key held down on the running instance of vhs.
  def self.execute_ctrl(cmd : Parser::Command, v : VHS) : Exception?
    page = v.page
    return Exception.new("vhs is not started") if page.nil?

    action = page.keyboard.key_actions.press(Rod::Input::CONTROL_LEFT)
    keys = cmd.args.split(' ')

    keys.each_with_index do |key, i|
      input_key = ctrl_input_key(key)
      next if input_key.nil?

      # The last key is typed; the rest stay pressed until the chain ends.
      if i == keys.size - 1
        action.type(input_key)
      else
        action.press(input_key)
      end
    end

    action.do
    nil
  end

  # ctrl_input_key resolves one link of a Ctrl chain (modifiers and named keys).
  private def self.ctrl_input_key(key : String) : Rod::Input::Key?
    case key
    when "Shift"     then Rod::Input::SHIFT_LEFT
    when "Alt"       then Rod::Input::ALT_LEFT
    when "Enter"     then Rod::Input::ENTER
    when "Space"     then Rod::Input::SPACE
    when "Backspace" then Rod::Input::BACKSPACE
    else
      first = key[0]?
      Keys.key_for(first) if first
    end
  end

  # ExecuteAlt is a CommandFunc that presses the argument key with the alt key
  # held down on the running instance of vhs.
  def self.execute_alt(cmd : Parser::Command, v : VHS) : Exception?
    page = v.page
    return Exception.new("vhs is not started") if page.nil?

    keyboard = page.keyboard
    keyboard.press(Rod::Input::ALT_LEFT)
    begin
      case Token.lookup_identifier(cmd.args)
      when Token::ENTER
        keyboard.type(Rod::Input::ENTER)
      when Token::TAB
        keyboard.type(Rod::Input::TAB)
      else
        type_mapped_runes(keyboard, cmd.args)
      end
    ensure
      keyboard.release(Rod::Input::ALT_LEFT)
    end

    nil
  end

  # ExecuteShift is a CommandFunc that presses the argument key with the shift
  # key held down on the running instance of vhs.
  def self.execute_shift(cmd : Parser::Command, v : VHS) : Exception?
    page = v.page
    return Exception.new("vhs is not started") if page.nil?

    keyboard = page.keyboard
    keyboard.press(Rod::Input::SHIFT_LEFT)
    begin
      case Token.lookup_identifier(cmd.args)
      when Token::ENTER
        keyboard.type(Rod::Input::ENTER)
      when Token::TAB
        keyboard.type(Rod::Input::TAB)
      else
        type_mapped_runes(keyboard, cmd.args)
      end
    ensure
      keyboard.release(Rod::Input::SHIFT_LEFT)
    end

    nil
  end

  # ExecuteSource reads and executes commands from a file.
  def self.execute_source(cmd : Parser::Command, v : VHS) : Exception?
    path = cmd.args
    if path.empty?
      return Exception.new("source path is required")
    end

    begin
      content = File.read(path)
    rescue ex : File::NotFoundError
      return Exception.new("source file not found: #{path}")
    end

    l = Lexer.new(content)
    p = Parser.new(l)
    cmds = p.parse
    errs = p.errors
    if !errs.empty? || cmds.empty?
      return Exception.new("parser errors in source file")
    end

    # Execute commands in current VHS instance
    cmds.each do |sub_cmd|
      err = execute(sub_cmd, v)
      return err if err
    end

    nil
  end

  # ExecuteSetFontSize applies the font size on the vhs.
  def self.execute_set_font_size(cmd : Parser::Command, v : VHS) : Exception?
    font_size = cmd.args.to_i32?
    if font_size.nil? || font_size <= 0
      return Exception.new("invalid font size: #{cmd.args}")
    end
    v.options.font_size = font_size
    nil
  end

  # ExecuteSetFontFamily applies the font family on the vhs.
  def self.execute_set_font_family(cmd : Parser::Command, v : VHS) : Exception?
    v.options.font_family = cmd.args
    nil
  end

  # ExecuteSetShell applies the shell on the vhs.
  def self.execute_set_shell(cmd : Parser::Command, v : VHS) : Exception?
    shell_name = cmd.args
    shell = SHELLS[shell_name]?
    if shell.nil?
      return Exception.new("invalid shell: #{shell_name}")
    end
    v.options.shell = shell
    nil
  end

  # ExecuteSetTheme applies the theme on the vhs.
  def self.execute_set_theme(cmd : Parser::Command, v : VHS) : Exception?
    theme = get_theme(cmd.args)
    v.options.theme = theme
    nil
  rescue ex : ThemeNotFoundError | InvalidThemeError
    ex
  end

  # ExecuteSetTypingSpeed applies the default typing speed on the vhs.
  def self.execute_set_typing_speed(cmd : Parser::Command, v : VHS) : Exception?
    typing_speed = Vhs.parse_duration(cmd.args)
    if typing_speed.nil?
      return Exception.new("failed to parse typing speed: #{cmd.args}")
    end

    v.options.typing_speed = typing_speed
    nil
  end

  # ExecuteSetFramerate applies the framerate on the vhs.
  def self.execute_set_framerate(cmd : Parser::Command, v : VHS) : Exception?
    framerate = cmd.args.to_i32?
    if framerate.nil? || framerate <= 0
      return Exception.new("invalid framerate: #{cmd.args}")
    end
    v.options.video.framerate = framerate
    nil
  end

  # ExecuteSetHeight applies the height on the vhs.
  def self.execute_set_height(cmd : Parser::Command, v : VHS) : Exception?
    height = cmd.args.to_i32?
    if height.nil? || height <= 0
      return Exception.new("invalid height: #{cmd.args}")
    end
    v.options.style.height = height
    nil
  end

  # ExecuteSetLetterSpacing applies the letter spacing on the vhs.
  def self.execute_set_letter_spacing(cmd : Parser::Command, v : VHS) : Exception?
    letter_spacing = cmd.args.to_f64?
    if letter_spacing.nil? || letter_spacing <= 0.0
      return Exception.new("invalid letter spacing: #{cmd.args}")
    end
    v.options.letter_spacing = letter_spacing
    nil
  end

  # ExecuteSetLineHeight applies the line height on the vhs.
  def self.execute_set_line_height(cmd : Parser::Command, v : VHS) : Exception?
    line_height = cmd.args.to_f64?
    if line_height.nil? || line_height <= 0.0
      return Exception.new("invalid line height: #{cmd.args}")
    end
    v.options.line_height = line_height
    nil
  end

  # ExecuteSetPlaybackSpeed applies the playback speed on the vhs.
  def self.execute_set_playback_speed(cmd : Parser::Command, v : VHS) : Exception?
    playback_speed = cmd.args.to_f64?
    if playback_speed.nil? || playback_speed <= 0.0
      return Exception.new("invalid playback speed: #{cmd.args}")
    end
    v.options.video.playback_speed = playback_speed
    nil
  end

  # ExecuteSetPadding applies the padding on the vhs.
  def self.execute_set_padding(cmd : Parser::Command, v : VHS) : Exception?
    padding = cmd.args.to_i32?
    if padding.nil? || padding < 0
      return Exception.new("invalid padding: #{cmd.args}")
    end
    v.options.style.padding = padding
    nil
  end

  # ExecuteSetWidth applies the width on the vhs.
  def self.execute_set_width(cmd : Parser::Command, v : VHS) : Exception?
    width = cmd.args.to_i32?
    if width.nil? || width <= 0
      return Exception.new("invalid width: #{cmd.args}")
    end
    v.options.style.width = width
    nil
  end

  # ExecuteLoopOffset applies the loop offset on the vhs.
  def self.execute_loop_offset(cmd : Parser::Command, v : VHS) : Exception?
    # The parser always appends "%", so the offset has to be trimmed before
    # parsing (upstream does the same with strings.TrimRight).
    loop_offset = cmd.args.rstrip('%').to_f64?
    if loop_offset.nil? || loop_offset < 0.0
      return Exception.new("invalid loop offset: #{cmd.args}")
    end
    v.options.loop_offset = loop_offset
    nil
  end

  # ExecuteSetMarginFill applies the margin fill on the vhs.
  def self.execute_set_margin_fill(cmd : Parser::Command, v : VHS) : Exception?
    v.options.style.margin_fill = cmd.args
    nil
  end

  # ExecuteSetMargin applies the margin on the vhs.
  def self.execute_set_margin(cmd : Parser::Command, v : VHS) : Exception?
    margin = cmd.args.to_i32?
    if margin.nil? || margin < 0
      return Exception.new("invalid margin: #{cmd.args}")
    end
    v.options.style.margin = margin
    nil
  end

  # ExecuteSetWindowBar applies the window bar on the vhs.
  def self.execute_set_window_bar(cmd : Parser::Command, v : VHS) : Exception?
    v.options.style.window_bar = cmd.args
    nil
  end

  # ExecuteSetWindowBarSize applies the window bar size on the vhs.
  def self.execute_set_window_bar_size(cmd : Parser::Command, v : VHS) : Exception?
    window_bar_size = cmd.args.to_i32?
    if window_bar_size.nil? || window_bar_size < 0
      return Exception.new("invalid window bar size: #{cmd.args}")
    end
    v.options.style.window_bar_size = window_bar_size
    nil
  end

  # ExecuteSetBorderRadius applies the border radius on the vhs.
  def self.execute_set_border_radius(cmd : Parser::Command, v : VHS) : Exception?
    border_radius = cmd.args.to_i32?
    if border_radius.nil? || border_radius < 0
      return Exception.new("invalid border radius: #{cmd.args}")
    end
    v.options.style.border_radius = border_radius
    nil
  end

  # ExecuteSetWaitPattern applies the wait pattern on the vhs.
  def self.execute_set_wait_pattern(cmd : Parser::Command, v : VHS) : Exception?
    begin
      pattern = Regex.new(cmd.args)
    rescue ex
      return Exception.new("invalid regex pattern: #{cmd.args}")
    end
    v.options.wait_pattern = pattern
    nil
  end

  # ExecuteSetWaitTimeout applies the wait timeout on the vhs.
  def self.execute_set_wait_timeout(cmd : Parser::Command, v : VHS) : Exception?
    wait_timeout = Vhs.parse_duration(cmd.args)
    if wait_timeout.nil? || wait_timeout <= 0.seconds
      return Exception.new("failed to parse wait timeout: #{cmd.args}")
    end

    v.options.wait_timeout = wait_timeout
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
    v.options.cursor_blink = cursor_blink
    nil
  end

  # ExecuteKey is a higher-order function that returns a CommandFunc to execute
  # a key press for a given key. This is so that the logic for key pressing
  # (since they are repeatable and delayable) can be re-used.
  def self.execute_key(key : String) : CommandFunc
    ->(cmd : Parser::Command, v : VHS) : Exception? {
      page = v.page
      return Exception.new("vhs is not started") if page.nil?

      # Upstream takes the repeat count from the command's args and the per-key
      # speed from its @duration option, defaulting to the global typing speed.
      repeat = cmd.args.to_i? || 1
      typing_speed = Vhs.parse_duration(cmd.options) || v.options.typing_speed
      first = key[0]?
      input_key = (first ? Keys.key_for(first) : nil) || KEY_NAMES[key]?

      repeat.times do
        if input_key
          page.keyboard.type(input_key)
        else
          page.element("textarea").input(key)
        end
        sleep(typing_speed) if typing_speed > 0.milliseconds
      end

      nil
    }
  end

  # KEY_NAMES maps the key commands' names to the browser input keys, mirroring
  # the ExecuteKey(...) table upstream builds from go-rod's input package.
  KEY_NAMES = {
    "Enter"      => Rod::Input::ENTER,
    "Backspace"  => Rod::Input::BACKSPACE,
    "Delete"     => Rod::Input::DELETE,
    "Insert"     => Rod::Input::INSERT,
    "Tab"        => Rod::Input::TAB,
    "Escape"     => Rod::Input::ESCAPE,
    "Space"      => Rod::Input::SPACE,
    "ArrowUp"    => Rod::Input::ARROW_UP,
    "ArrowDown"  => Rod::Input::ARROW_DOWN,
    "ArrowRight" => Rod::Input::ARROW_RIGHT,
    "ArrowLeft"  => Rod::Input::ARROW_LEFT,
    "PageUp"     => Rod::Input::PAGE_UP,
    "PageDown"   => Rod::Input::PAGE_DOWN,
    "Home"       => Rod::Input::HOME,
    "End"        => Rod::Input::END,
  }

  # type_mapped_runes types every rune that has a browser key mapping.
  private def self.type_mapped_runes(keyboard : Rod::Keyboard, text : String) : Nil
    text.each_char do |char|
      key = Keys.key_for(char)
      keyboard.type(key) if key
    end
  end

  # type_text types a string through the browser keyboard, falling back to the
  # page's textarea input for runes without a key mapping (upstream ExecuteType
  # does the same).
  private def self.type_text(page : Rod::Page, text : String) : Nil
    text.each_char do |char|
      if key = Keys.key_for(char)
        page.keyboard.type(key)
      else
        page.element("textarea").input(char.to_s)
      end
    end
  end

  # StyleOptions represents the ui options for video and screenshots.
  #
  # A class (reference semantics) because upstream shares one *StyleOptions
  # between Options, Video, and Screenshot, so a Set command is visible to every
  # renderer without copying.
  class StyleOptions
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
      @width : Int32 = 0,
      @height : Int32 = 0,
      @padding : Int32 = 0,
      @background_color : String = "",
      @margin_fill : String = "",
      @margin : Int32 = 0,
      @window_bar : String = "",
      @window_bar_size : Int32 = 0,
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
  # A class for the same reason: upstream mutates ScreenshotOptions through
  # pointer-receiver methods (makeScreenshot, enableFrameCapture).
  class ScreenshotOptions
    property? frame_capture : Bool
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

  # DefaultTestOptions returns the default set of options for the testing
  # functionality. Nothing calls it upstream either (DefaultVHSOptions uses the
  # zero value), but it is part of the package surface.
  def self.default_test_options : TestOptions
    TestOptions.new(output: "out.test")
  end

  # Shell is a type that contains a prompt and the command to set up the shell.
  struct Shell
    property command : Array(String)
    property env : Array(String)

    def initialize(*, @command = ["sh"], @env = [] of String)
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
    property wait_pattern : Regex?
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
      @wait_pattern = nil,
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

  # EvaluatorOption is a function that can be used to modify the VHS instance
  # before it renders.
  alias EvaluatorOption = VHS -> Nil

  # Evaluate takes as input a tape string, an output writer, and an output file
  # and evaluates all the commands within the tape string and produces a GIF.
  #
  # Options are applied after every command has run and recording has stopped,
  # which is where upstream applies them: an option can read the tape's final
  # settings and override the output paths before rendering.
  #
  # Two overloads are needed because a typed splat parameter in Crystal requires
  # at least one argument, so the no-option call needs its own signature.
  def self.evaluate(tape : String, output : IO = STDOUT) : Array(Exception)
    evaluate_tape(tape, output, [] of EvaluatorOption)
  end

  def self.evaluate(tape : String, output : IO, *opts : EvaluatorOption) : Array(Exception)
    evaluate_tape(tape, output, opts.to_a)
  end

  private def self.evaluate_tape(tape : String, output : IO, opts : Array(EvaluatorOption)) : Array(Exception)
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

    # Start ttyd and the browser, then configure the session (upstream's
    # Start followed by Setup). Recording starts later, after the header.
    if err = v.start
      v.errors << err
    end

    if err = v.setup
      v.errors << err
    end

    # Whatever happens next, recording stops and the frame directories are
    # removed: an early return (bad setting, undersized video, failing command)
    # must not leave the capture fiber running.
    begin
      # Settings, outputs, and requires run first and are echoed in full color.
      # Divergence: upstream starts recording after this loop; the port starts
      # capture in Start, before it.
      offset = cmds.size
      cmds.each_with_index do |cmd, i|
        if cmd.type == Token::SET || cmd.type == Token::OUTPUT || cmd.type == Token::REQUIRE
          output.puts Highlight.highlight(cmd, false)
          if cmd.options != "Shell"
            err = execute(cmd, v)
            return [err] of Exception if err
          end
        else
          offset = i
          break
        end
      end

      # Make sure the image is big enough to fit the padding, bar, and margins.
      video = v.options.video
      min_width = double(video.style.padding) + double(video.style.margin)
      min_height = double(video.style.padding) + double(video.style.margin)
      unless video.style.window_bar.empty?
        min_height += video.style.window_bar_size
      end
      if video.style.height < min_height || video.style.width < min_width
        v.errors << Exception.new("Dimensions must be at least #{min_width} x #{min_height}")
      end

      if !v.errors.empty?
        v.stop
        v.cleanup
        return v.errors
      end

      # If the first command after the header is Hide, run forward to the
      # matching Show before recording starts, so hidden frames are never
      # captured (upstream does the same before Record).
      if offset < cmds.size && cmds[offset].type == Token::HIDE
        cmds[offset..].each_with_index do |cmd, i|
          if cmd.type == Token::SHOW
            offset += i
            break
          end

          output.puts Highlight.highlight(cmd, true)
          if err = execute(cmd, v)
            v.stop
            v.cleanup
            return [err] of Exception
          end
        end
      end

      # Recording starts here, like upstream's Record(ctx) after the header.
      v.begin_recording

      # Remaining commands execute in order. Settings after the header are ignored
      # with a warning, matching upstream.
      cmds[offset..].each do |cmd|
        is_setting = cmd.type == Token::SET && cmd.options != "TypingSpeed"
        if is_setting
          # Upstream prints this warning to stdout, not stderr.
          puts Styles::ERROR_STYLE.render(
            "WARN: 'Set #{cmd.options} #{cmd.args}' has been ignored. " \
            "Move the directive to the top of the file.\n" \
            "Learn more: https://github.com/charmbracelet/vhs#settings"
          )
        end
        if is_setting || cmd.type == Token::REQUIRE
          output.puts Highlight.highlight(cmd, true)
          next
        end

        output.puts Highlight.highlight(
          cmd,
          !v.recording? || cmd.type == Token::SHOW || cmd.type == Token::HIDE
        )

        if err = execute(cmd, v)
          v.stop
          v.cleanup
          return [err] of Exception
        end
      end

      # Stop VHS
      v.stop
      sleep 0.05.seconds

      # Upstream applies the evaluator options here, after all settings and
      # commands have run and recording has been torn down, so an option sees the
      # tape's final options and can still redirect the outputs.
      opts.each(&.call(v))

      # Render the video outputs and any deferred screenshots.
      if err = v.render
        return [err] of Exception
      end

      # Move the frames to the configured directory (Output with a trailing
      # slash), then clean up the temporary frame and screenshot directories.
      #
      # Divergence: upstream renames to the raw argument, and a trailing slash makes
      # that rename fail silently; the port trims it so the documented
      # `Output frames/` works.
      frames = v.options.video.output.frames
      if !frames.empty? && Dir.exists?(v.options.video.input)
        File.rename(v.options.video.input, frames.rstrip('/')) rescue nil
      end

      v.errors
    ensure
      v.stop
      v.cleanup
    end
  end

  # VHS is the object that controls the setup.
  class VHS
    property options : Options
    property errors : Array(Exception)
    property? started : Bool
    property? recording : Bool
    property total_frames : Int32
    property page : Rod::Page?
    property browser : Rod::Browser?
    property text_canvas : Rod::Element?
    property cursor_canvas : Rod::Element?
    property tty : Process?
    property launcher : Rod::Util::Launcher::Launcher?
    property mutex : Mutex
    property frame_capture_fiber : Fiber?
    property? stop_frame_capture : Bool
    property? test_output_created : Bool

    # cleanupWaitTime is how long commands such as `rm` get to finish before the
    # browser and ttyd are torn down.
    CLEANUP_WAIT_TIME = 100.milliseconds

    # quality is the PNG quality passed to the canvas capture.
    CANVAS_QUALITY = 1.0

    def initialize
      # Upstream New() seeds the instance with DefaultVHSOptions, so a bare
      # VHS.new already carries the default shell, fonts, and video paths.
      @options = Vhs.default_vhs_options
      @errors = [] of Exception
      @started = false
      @recording = true
      @total_frames = 0
      @page = nil
      @browser = nil
      @text_canvas = nil
      @cursor_canvas = nil
      @tty = nil
      @launcher = nil
      @mutex = Mutex.new
      @frame_capture_fiber = nil
      @stop_frame_capture = false
      @test_output_created = false
    end

    # Start starts ttyd, the browser, and the ttyd page.
    #
    # Mirrors upstream Start: pick a port, run ttyd for the configured shell,
    # launch the browser (no sandbox when VHS_NO_SANDBOX is set, leakless off),
    # connect, and open the ttyd URL.
    def start : Exception?
      @mutex.lock
      begin
        return Exception.new("vhs is already started") if started?

        port = Tty.random_port
        @tty = Tty.start(port, @options.shell)

        launcher = Rod::Util::Launcher::Launcher.new
        launcher.leakless(false)
        path, found = Rod::Util::Launcher::Browser.look_path
        launcher.bin(path.as(String)) if found && path
        launcher.no_sandbox(true) unless ENV["VHS_NO_SANDBOX"]?.nil?
        control_url = launcher.launch
        @launcher = launcher

        browser = Rod::Browser.new
        browser.connect(control_url)
        @browser = browser

        url = "http://localhost:#{port}"
        @page = browser.page(url)

        # Wait until xterm.js attached `window.term`, like upstream.
        @page.try(&.wait(Rod::EvalOptions.new(js: "() => window.term != undefined")))

        ensure_input_dir
        @started = true
        nil
      ensure
        @mutex.unlock
      end
    rescue ex
      ex
    end

    # begin_recording starts capturing frames. Upstream starts recording after
    # Start, Setup, and the settings/output header (plus any initial Hide
    # fast-forward), so those commands are not captured; callers that just want a
    # running terminal can skip this.
    def begin_recording : Nil
      start_frame_capture
    end

    # Stop stops recording and cleans up resources.
    def stop : Nil
      @mutex.lock
      begin
        return unless @started
        @recording = false
        stop_frame_capture
        terminate
        @started = false
      ensure
        @mutex.unlock
      end
    end

    # terminate tears down the browser and ttyd, giving in-flight commands a
    # moment to finish first (upstream's cleanupWaitTime).
    def terminate : Nil
      sleep CLEANUP_WAIT_TIME
      @browser.try(&.close)
      @launcher.try(&.kill)
      tty = @tty
      if tty
        tty.terminate rescue nil
        @tty = nil
      end
      @page = nil
      @browser = nil
      @text_canvas = nil
      @cursor_canvas = nil
    end

    # Ensure video input directory exists
    private def ensure_input_dir : Nil
      input_dir = @options.video.input
      return if input_dir.empty?
      Dir.mkdir_p(input_dir)
    end

    # Start frame capture loop
    def start_frame_capture : Nil
      # The recording flag is checked per frame, not here: upstream starts the
      # recorder and lets Hide/Show gate the captures inside the loop.
      return if @frame_capture_fiber

      interval = 1.second / @options.video.framerate
      @stop_frame_capture = false

      @frame_capture_fiber = spawn do
        loop do
          break if stop_frame_capture?
          sleep interval
          break if stop_frame_capture?
          next unless @recording

          capture_frame
        end
      end
    end

    # Stop frame capture loop
    def stop_frame_capture : Nil
      @stop_frame_capture = true
      @frame_capture_fiber = nil
    end

    # Captures one frame by reading the xterm.js text and cursor canvases, like
    # upstream's Record.
    def capture_frame : Nil
      page = @page
      return unless page

      cursor_canvas = @cursor_canvas
      text_canvas = @text_canvas
      return if cursor_canvas.nil? || text_canvas.nil?

      cursor = cursor_canvas.canvas_to_image("image/png", CANVAS_QUALITY)
      text = text_canvas.canvas_to_image("image/png", CANVAS_QUALITY)

      frame_num = @total_frames + 1
      input = @options.video.input
      File.write(File.join(input, sprintf(CURSOR_FRAME_FORMAT, frame_num)), cursor)
      File.write(File.join(input, sprintf(TEXT_FRAME_FORMAT, frame_num)), text)

      @total_frames += 1

      # Capture the current frame and disable frame capturing, like upstream
      # Record does after writing both layers.
      @options.screenshot.make_screenshot(@total_frames) if @options.screenshot.frame_capture?
    rescue ex
      @errors << ex
    end

    # Close stops recording and cleans up resources
    def close : Nil
      stop_frame_capture
      terminate
      @started = false
      @recording = false
    end

    # Render starts rendering the individual frames into a video.
    def render : Exception?
      if err = apply_loop_offset
        return err
      end

      # Generate the video(s) with the frames using FFmpeg.
      ::Vhs::FFmpegRenderer.render(@options.video, @options.screenshot)
    end

    # ApplyLoopOffset shifts the first frames to the end of the sequence, which
    # turns a recording into a seamless loop. Upstream renames the text and
    # cursor frames concurrently; the rename is sequential here, same result.
    def apply_loop_offset : Exception?
      return Exception.new("no frames") if @total_frames <= 0

      loop_offset_frames = (@options.loop_offset / 100.0 * @total_frames).ceil.to_i
      loop_offset_frames = loop_offset_frames % @total_frames
      return nil if loop_offset_frames <= 0

      offset_start = @options.video.starting_frame
      offset_end = loop_offset_frames
      @options.video.starting_frame = offset_end + 1

      input = @options.video.input
      (offset_start..offset_end).each do |frame_num|
        offset_frame_num = frame_num + @total_frames
        {CURSOR_FRAME_FORMAT, TEXT_FRAME_FORMAT}.each do |format|
          File.rename(
            File.join(input, sprintf(format, frame_num)),
            File.join(input, sprintf(format, offset_frame_num))
          )
        rescue ex
          return Exception.new("error applying offset to frame: #{ex.message}")
        end
      end

      nil
    end

    # Setup configures the browser session once the settings have run.
    #
    # Mirrors upstream Setup: size the viewport to fit padding, margins, and the
    # window bar; find the xterm.js text and cursor canvases; push the terminal
    # options; fit the terminal; and re-create the frames directory.
    def setup : Exception?
      page = @page
      return Exception.new("vhs is not started") if page.nil?

      style = @options.style
      padding = style.padding
      margin = style.margin_fill.empty? ? 0 : style.margin
      bar = style.window_bar.empty? ? 0 : style.window_bar_size
      width = style.width - padding * 2 - margin * 2
      height = style.height - padding * 2 - margin * 2 - bar

      page.set_viewport(
        Cdp::Emulation::SetDeviceMetricsOverride.new(
          width: width.to_i64,
          height: height.to_i64,
          device_scale_factor: 0.0,
          mobile: false
        )
      )

      @text_canvas = page.element("canvas.xterm-text-layer")
      @cursor_canvas = page.element("canvas.xterm-cursor-layer")

      options = @options
      page.eval(
        "() => { term.options = { fontSize: #{options.font_size}, " \
        "fontFamily: '#{options.font_family}', letterSpacing: #{options.letter_spacing}, " \
        "lineHeight: #{options.line_height}, theme: #{options.theme.to_json}, " \
        "cursorBlink: #{options.cursor_blink?} } }"
      )
      page.eval("term.fit")

      input = options.video.input
      unless input.empty?
        remove_tree(input)
        Dir.mkdir_p(input)
        File.chmod(input, 0o750)
      end

      nil
    rescue ex
      ex
    end

    # Cleanup removes the frame and screenshot directories.
    def cleanup : Exception?
      [@options.video.input, @options.screenshot.input].each do |dir|
        next if dir.empty?

        remove_tree(dir)
      end
      nil
    rescue ex
      ex
    end

    # remove_tree deletes a directory tree.
    #
    # This checkout lives on an exFAT volume where AppleDouble `._*` sidecars are
    # created and removed asynchronously, so a single FileUtils.rm_rf can leave
    # entries behind; retry until the directory is gone.
    private def remove_tree(dir : String) : Nil
      return unless Dir.exists?(dir)

      10.times do
        begin
          FileUtils.rm_rf(dir)
        rescue File::NotFoundError
          # A sidecar vanished between listing and unlinking.
        end
        return unless Dir.exists?(dir)

        sleep 10.milliseconds
      end
    end

    # Buffer returns the current terminal buffer lines, trimmed at the end, read
    # from xterm.js like upstream.
    def buffer : Array(String)
      page = @page
      return [] of String unless page

      result = page.eval(
        "() => Array(term.rows).fill(0).map((e, i) => " \
        "term.buffer.active.getLine(i).translateToString().trimEnd())"
      )
      values = result.value.try(&.as_a?) || [] of JSON::Any
      values.map(&.as_s)
    rescue ex
      @errors << ex
      [] of String
    end

    # CurrentLine returns the line the cursor is on, trimmed at the end, like
    # upstream's cursorY + viewportY lookup.
    def current_line : String
      page = @page
      return "" unless page

      result = page.eval(
        "() => term.buffer.active.getLine(term.buffer.active.cursorY+" \
        "term.buffer.active.viewportY).translateToString().trimEnd()"
      )
      result.value.try(&.as_s?) || ""
    rescue ex
      @errors << ex
      ""
    end

    # SaveOutput appends the current buffer plus a separator to the test output
    # file. Upstream creates (truncates) that file once, then appends on later
    # calls; the port does the same with a per-instance flag.
    def save_output : Exception?
      output_path = @options.test.output
      return nil if output_path.empty?

      dir = File.dirname(output_path)
      begin
        FileUtils.mkdir_p(dir) unless dir.empty? || Dir.exists?(dir)
      rescue ex
        # Upstream falls back to a temporary file when the output directory
        # cannot be created.
        output_path = File.tempname("vhs-", ".txt")
      end

      separator = SEPARATOR
      mode = @test_output_created ? "a" : "w"

      begin
        File.open(output_path, mode) do |file|
          buffer.each { |line| file.puts(line) }
          file.puts(separator)
        end
        @test_output_created = true
      rescue ex
        return ex
      end

      nil
    end
  end
end
