module Vhs
  # Token module provides the token types and structures for the VHS Tape language.
  module Token
    # Type represents a token's type (alias for Symbol for efficiency).
    alias Type = Symbol

    # Punctuation and symbols
    AT            = :"@"
    EQUAL         = :"="
    PLUS          = :"+"
    PERCENT       = :"%"
    SLASH         = :"/"
    BACKSLASH     = :"\\"
    DOT           = :"."
    DASH          = :"-"
    MINUS         = :"-"
    RIGHT_BRACKET = :"]"
    LEFT_BRACKET  = :"["
    CARET         = :"^"

    # Units
    EM           = :EM
    MILLISECONDS = :MILLISECONDS
    MINUTES      = :MINUTES
    PX           = :PX
    SECONDS      = :SECONDS

    # Special
    EOF     = :EOF
    ILLEGAL = :ILLEGAL

    # Commands
    ALT       = :ALT
    BACKSPACE = :BACKSPACE
    CTRL      = :CTRL
    DELETE    = :DELETE
    END       = :END
    ENTER     = :ENTER
    ESCAPE    = :ESCAPE
    HOME      = :HOME
    INSERT    = :INSERT
    PAGE_DOWN = :PAGE_DOWN
    PAGE_UP   = :PAGE_UP
    SLEEP     = :SLEEP
    SPACE     = :SPACE
    TAB       = :TAB
    SHIFT     = :SHIFT

    # Values
    COMMENT = :COMMENT
    NUMBER  = :NUMBER
    STRING  = :STRING
    JSON    = :JSON
    REGEX   = :REGEX
    BOOLEAN = :BOOLEAN

    # Arrow keys
    DOWN  = :DOWN
    LEFT  = :LEFT
    RIGHT = :RIGHT
    UP    = :UP

    # Special commands
    HIDE       = :HIDE
    OUTPUT     = :OUTPUT
    REQUIRE    = :REQUIRE
    SET        = :SET
    SHOW       = :SHOW
    SOURCE     = :SOURCE
    TYPE       = :TYPE
    SCREENSHOT = :SCREENSHOT
    COPY       = :COPY
    PASTE      = :PASTE
    SHELL      = :SHELL
    ENV        = :ENV

    # Settings
    FONT_FAMILY     = :FONT_FAMILY
    FONT_SIZE       = :FONT_SIZE
    FRAMERATE       = :FRAMERATE
    PLAYBACK_SPEED  = :PLAYBACK_SPEED
    HEIGHT          = :HEIGHT
    WIDTH           = :WIDTH
    LETTER_SPACING  = :LETTER_SPACING
    LINE_HEIGHT     = :LINE_HEIGHT
    TYPING_SPEED    = :TYPING_SPEED
    PADDING         = :PADDING
    THEME           = :THEME
    LOOP_OFFSET     = :LOOP_OFFSET
    MARGIN_FILL     = :MARGIN_FILL
    MARGIN          = :MARGIN
    WINDOW_BAR      = :WINDOW_BAR
    WINDOW_BAR_SIZE = :WINDOW_BAR_SIZE
    BORDER_RADIUS   = :CORNER_RADIUS
    WAIT            = :WAIT
    WAIT_TIMEOUT    = :WAIT_TIMEOUT
    WAIT_PATTERN    = :WAIT_PATTERN
    CURSOR_BLINK    = :CURSOR_BLINK

    # Token represents a lexer token.
    struct Token
      getter type : Type
      getter literal : String
      getter line : Int32
      getter column : Int32

      def initialize(@type : Type, @literal : String, @line : Int32, @column : Int32)
      end

      def to_s(io : IO) : Nil
        io << "Token(type=#{type}, literal=#{literal.inspect}, line=#{line}, column=#{column})"
      end
    end

    # Keywords maps keyword strings to tokens.
    KEYWORDS = {
      "em"            => EM,
      "px"            => PX,
      "ms"            => MILLISECONDS,
      "s"             => SECONDS,
      "m"             => MINUTES,
      "Set"           => SET,
      "Sleep"         => SLEEP,
      "Type"          => TYPE,
      "Enter"         => ENTER,
      "Space"         => SPACE,
      "Backspace"     => BACKSPACE,
      "Delete"        => DELETE,
      "Insert"        => INSERT,
      "Ctrl"          => CTRL,
      "Alt"           => ALT,
      "Shift"         => SHIFT,
      "Down"          => DOWN,
      "Left"          => LEFT,
      "Right"         => RIGHT,
      "Up"            => UP,
      "PageUp"        => PAGE_UP,
      "PageDown"      => PAGE_DOWN,
      "Tab"           => TAB,
      "Escape"        => ESCAPE,
      "End"           => END,
      "Hide"          => HIDE,
      "Require"       => REQUIRE,
      "Show"          => SHOW,
      "Output"        => OUTPUT,
      "Shell"         => SHELL,
      "FontFamily"    => FONT_FAMILY,
      "MarginFill"    => MARGIN_FILL,
      "Margin"        => MARGIN,
      "WindowBar"     => WINDOW_BAR,
      "WindowBarSize" => WINDOW_BAR_SIZE,
      "BorderRadius"  => BORDER_RADIUS,
      "FontSize"      => FONT_SIZE,
      "Framerate"     => FRAMERATE,
      "Height"        => HEIGHT,
      "LetterSpacing" => LETTER_SPACING,
      "LineHeight"    => LINE_HEIGHT,
      "PlaybackSpeed" => PLAYBACK_SPEED,
      "TypingSpeed"   => TYPING_SPEED,
      "Padding"       => PADDING,
      "Theme"         => THEME,
      "Width"         => WIDTH,
      "LoopOffset"    => LOOP_OFFSET,
      "WaitTimeout"   => WAIT_TIMEOUT,
      "WaitPattern"   => WAIT_PATTERN,
      "Wait"          => WAIT,
      "Source"        => SOURCE,
      "CursorBlink"   => CURSOR_BLINK,
      "true"          => BOOLEAN,
      "false"         => BOOLEAN,
      "Screenshot"    => SCREENSHOT,
      "Copy"          => COPY,
      "Paste"         => PASTE,
      "Env"           => ENV,
    }

    # IsSetting returns whether a token is a setting.
    def self.setting?(type : Type) : Bool
      case type
      when SHELL, FONT_FAMILY, FONT_SIZE, LETTER_SPACING, LINE_HEIGHT,
           FRAMERATE, TYPING_SPEED, THEME, PLAYBACK_SPEED, HEIGHT, WIDTH,
           PADDING, LOOP_OFFSET, MARGIN_FILL, MARGIN, WINDOW_BAR,
           WINDOW_BAR_SIZE, BORDER_RADIUS, CURSOR_BLINK, WAIT_TIMEOUT, WAIT_PATTERN
        true
      else
        false
      end
    end

    # IsCommand returns whether the string is a command.
    def self.command?(type : Type) : Bool
      case type
      when TYPE, SLEEP,
           UP, DOWN, RIGHT, LEFT, PAGE_UP, PAGE_DOWN,
           ENTER, BACKSPACE, DELETE, TAB,
           ESCAPE, HOME, INSERT, END, CTRL, SOURCE, SCREENSHOT, COPY, PASTE, WAIT
        true
      else
        false
      end
    end

    # IsModifier returns whether the token is a modifier.
    def self.modifier?(type : Type) : Bool
      type == ALT || type == SHIFT
    end

    # to_camel converts a snake_case string to CamelCase.
    def self.to_camel(s : String) : String
      parts = s.split('_')
      parts.map! do |part|
        if part.empty?
          ""
        else
          part[0].upcase + part[1..].downcase
        end
      end
      parts.join
    end

    # lookup_identifier returns whether the identifier is a keyword.
    # In `vhs`, there are no _actual_ identifiers, i.e. there are no variables.
    # Instead, identifiers are simply strings (i.e. bare words).
    def self.lookup_identifier(ident : String) : Type
      KEYWORDS[ident]? || STRING
    end

    # Converts a token type to its human readable string format.
    def self.to_human_readable(type : Type) : String
      if command?(type) || setting?(type)
        to_camel(type.to_s)
      else
        type.to_s
      end
    end
  end
end
