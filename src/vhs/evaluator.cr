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
    property cursor_blink : Bool
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
    Dir.mktmpdir("vhs")
  end

  private def self.double(n : Int32) : Int32
    n * 2
  end

  # Evaluate takes as input a tape string, an output writer, and an output file
  # and evaluates all the commands within the tape string and produces a GIF.
  def self.evaluate(tape : String, output : IO = STDOUT) : Array(Exception)
    # TODO: Implement evaluation
    [] of Exception
  end

  # VHS is the object that controls the setup.
  class VHS
    property options : Options
    property errors : Array(Exception)
    property started : Bool
    property recording : Bool
    property total_frames : Int32

    def initialize
      @options = Options.new
      @errors = [] of Exception
      @started = false
      @recording = true
      @total_frames = 0
    end
  end
end
