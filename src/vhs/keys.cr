require "rod"

module Vhs
  # Key map for the Type and Paste commands, ported from upstream keys.go.
  #
  # Each rune of a string becomes the go-rod input that produces it; shifted
  # punctuation and letters are expressed through the shift helper, exactly as
  # upstream does.
  module Keys
    extend self

    # shift returns the key with the shift modifier applied.
    def shift(key : Rod::Input::Key) : Rod::Input::Key
      Rod::Input.shifted(key)[0]
    end

    @@keymap : Hash(Char, Rod::Input::Key)? = nil

    # keymap maps a rune to the input key that types it.
    def keymap : Hash(Char, Rod::Input::Key)
      @@keymap ||= build_keymap
    end

    # key_for returns the input key for a rune, or nil when there is no mapping
    # (upstream falls back to typing the text into the page's textarea).
    def key_for(char : Char) : Rod::Input::Key?
      keymap[char]?
    end

    private def build_keymap : Hash(Char, Rod::Input::Key)
      {
        ' '  => Rod::Input::SPACE,
        '!'  => shift(Rod::Input::DIGIT1),
        '"'  => shift(Rod::Input::QUOTE),
        '#'  => shift(Rod::Input::DIGIT3),
        '$'  => shift(Rod::Input::DIGIT4),
        '%'  => shift(Rod::Input::DIGIT5),
        '&'  => shift(Rod::Input::DIGIT7),
        '('  => shift(Rod::Input::DIGIT9),
        ')'  => shift(Rod::Input::DIGIT0),
        '*'  => shift(Rod::Input::DIGIT8),
        '+'  => shift(Rod::Input::EQUAL),
        ','  => Rod::Input::COMMA,
        '-'  => Rod::Input::MINUS,
        '.'  => Rod::Input::PERIOD,
        '/'  => Rod::Input::SLASH,
        '0'  => Rod::Input::DIGIT0,
        '1'  => Rod::Input::DIGIT1,
        '2'  => Rod::Input::DIGIT2,
        '3'  => Rod::Input::DIGIT3,
        '4'  => Rod::Input::DIGIT4,
        '5'  => Rod::Input::DIGIT5,
        '6'  => Rod::Input::DIGIT6,
        '7'  => Rod::Input::DIGIT7,
        '8'  => Rod::Input::DIGIT8,
        '9'  => Rod::Input::DIGIT9,
        ':'  => shift(Rod::Input::SEMICOLON),
        ';'  => Rod::Input::SEMICOLON,
        '<'  => shift(Rod::Input::COMMA),
        '='  => Rod::Input::EQUAL,
        '>'  => shift(Rod::Input::PERIOD),
        '?'  => shift(Rod::Input::SLASH),
        '@'  => shift(Rod::Input::DIGIT2),
        'A'  => shift(Rod::Input::KEY_A),
        'B'  => shift(Rod::Input::KEY_B),
        'C'  => shift(Rod::Input::KEY_C),
        'D'  => shift(Rod::Input::KEY_D),
        'E'  => shift(Rod::Input::KEY_E),
        'F'  => shift(Rod::Input::KEY_F),
        'G'  => shift(Rod::Input::KEY_G),
        'H'  => shift(Rod::Input::KEY_H),
        'I'  => shift(Rod::Input::KEY_I),
        'J'  => shift(Rod::Input::KEY_J),
        'K'  => shift(Rod::Input::KEY_K),
        'L'  => shift(Rod::Input::KEY_L),
        'M'  => shift(Rod::Input::KEY_M),
        'N'  => shift(Rod::Input::KEY_N),
        'O'  => shift(Rod::Input::KEY_O),
        'P'  => shift(Rod::Input::KEY_P),
        'Q'  => shift(Rod::Input::KEY_Q),
        'R'  => shift(Rod::Input::KEY_R),
        'S'  => shift(Rod::Input::KEY_S),
        'T'  => shift(Rod::Input::KEY_T),
        'U'  => shift(Rod::Input::KEY_U),
        'V'  => shift(Rod::Input::KEY_V),
        'W'  => shift(Rod::Input::KEY_W),
        'X'  => shift(Rod::Input::KEY_X),
        'Y'  => shift(Rod::Input::KEY_Y),
        'Z'  => shift(Rod::Input::KEY_Z),
        '['  => Rod::Input::BRACKET_LEFT,
        '\'' => Rod::Input::QUOTE,
        '\\' => Rod::Input::BACKSLASH,
        '\b' => Rod::Input::BACKSPACE,
        '\n' => Rod::Input::ENTER,
        '\r' => Rod::Input::ENTER,
        '\t' => Rod::Input::TAB,
        '\e' => Rod::Input::ESCAPE,
        ']'  => Rod::Input::BRACKET_RIGHT,
        '^'  => shift(Rod::Input::DIGIT6),
        '_'  => shift(Rod::Input::MINUS),
        '`'  => Rod::Input::BACKQUOTE,
        'a'  => Rod::Input::KEY_A,
        'b'  => Rod::Input::KEY_B,
        'c'  => Rod::Input::KEY_C,
        'd'  => Rod::Input::KEY_D,
        'e'  => Rod::Input::KEY_E,
        'f'  => Rod::Input::KEY_F,
        'g'  => Rod::Input::KEY_G,
        'h'  => Rod::Input::KEY_H,
        'i'  => Rod::Input::KEY_I,
        'j'  => Rod::Input::KEY_J,
        'k'  => Rod::Input::KEY_K,
        'l'  => Rod::Input::KEY_L,
        'm'  => Rod::Input::KEY_M,
        'n'  => Rod::Input::KEY_N,
        'o'  => Rod::Input::KEY_O,
        'p'  => Rod::Input::KEY_P,
        'q'  => Rod::Input::KEY_Q,
        'r'  => Rod::Input::KEY_R,
        's'  => Rod::Input::KEY_S,
        't'  => Rod::Input::KEY_T,
        'u'  => Rod::Input::KEY_U,
        'v'  => Rod::Input::KEY_V,
        'w'  => Rod::Input::KEY_W,
        'x'  => Rod::Input::KEY_X,
        'y'  => Rod::Input::KEY_Y,
        'z'  => Rod::Input::KEY_Z,
        '{'  => shift(Rod::Input::BRACKET_LEFT),
        '|'  => shift(Rod::Input::BACKSLASH),
        '}'  => shift(Rod::Input::BRACKET_RIGHT),
        '~'  => shift(Rod::Input::BACKQUOTE),
        '←'  => Rod::Input::ARROW_LEFT,
        '↑'  => Rod::Input::ARROW_UP,
        '→'  => Rod::Input::ARROW_RIGHT,
        '↓'  => Rod::Input::ARROW_DOWN,
      }
    end
  end
end
