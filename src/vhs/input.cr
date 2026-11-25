module Vhs
  # Input synthesises the byte sequences for tape key commands.
  #
  # Upstream drives keys through the browser's input layer (rod's
  # `input.Key` + key actions) and lets xterm.js turn them into escape
  # sequences. The headless port writes those sequences straight to the terminal
  # emulator, so this module is the single place the mapping lives.
  module Input
    extend self

    # Keys whose sequence is a fixed name lookup (ExecuteKey's table).
    KEY_SEQUENCES = {
      "Enter"      => "\n",
      "Backspace"  => "\b",
      "Delete"     => "\u007f",
      "Insert"     => "\e[2~",
      "Tab"        => "\t",
      "Escape"     => "\e",
      "Space"      => " ",
      "ArrowUp"    => "\e[A",
      "ArrowDown"  => "\e[B",
      "ArrowRight" => "\e[C",
      "ArrowLeft"  => "\e[D",
      "PageUp"     => "\e[5~",
      "PageDown"   => "\e[6~",
      "Home"       => "\e[1~",
      "End"        => "\e[4~",
    }

    # Named keys Alt+<key> sends as ESC followed by the key's own sequence.
    ALT_KEYS = {
      "enter"     => "\x1b\r",
      "tab"       => "\x1b\t",
      "space"     => "\x1b ",
      "backspace" => "\x1b\b",
    }

    # Shift turns a printable key into its shifted character.
    SHIFTED_CHARS = {
      '1'  => '!',
      '2'  => '@',
      '3'  => '#',
      '4'  => '$',
      '5'  => '%',
      '6'  => '^',
      '7'  => '&',
      '8'  => '*',
      '9'  => '(',
      '0'  => ')',
      '-'  => '_',
      '='  => '+',
      '['  => '{',
      ']'  => '}',
      '\\' => '|',
      ';'  => ':',
      '\'' => '"',
      ','  => '<',
      '.'  => '>',
      '/'  => '?',
      '`'  => '~',
    }

    # Ctrl writes the corresponding C0 control character; a few punctuation
    # keys have traditional mappings.
    CTRL_SEQUENCES = {
      "c"         => "\x03",
      "d"         => "\x04",
      "z"         => "\x1a",
      "["         => "\x1b",
      "\\"        => "\x1c",
      "]"         => "\x1d",
      "^"         => "\x1e",
      "_"         => "\x1f",
      "?"         => "\x7f",
      "enter"     => "\r",
      "space"     => "\x00",
      "backspace" => "\u007f",
    }

    # key_sequence returns the bytes for a named or single-character key.
    def key_sequence(key : String) : String
      KEY_SEQUENCES[key]? || key.downcase
    end

    # alt_sequence returns the bytes for Alt+<key>.
    def alt_sequence(key : String) : String
      return ALT_KEYS[key.downcase] if ALT_KEYS.has_key?(key.downcase)

      if key.size == 1
        "\x1b#{key}"
      else
        # Multi-character keys are sent as one Alt per character.
        key.each_char.map { |char| "\x1b#{char}" }.join
      end
    end

    # shift_sequence returns the bytes for Shift+<key>.
    def shift_sequence(key : String) : String
      case key.downcase
      when "enter"
        "\r"
      when "tab"
        "\x1b[Z" # backtab
      when "space"
        " "
      when "backspace"
        "\b"
      else
        return key.upcase if key.size != 1

        char = key[0]
        (SHIFTED_CHARS[char]? || char.upcase).to_s
      end
    end

    # ctrl_sequence returns the bytes for a Ctrl+<...> combination. Modifiers in
    # the chain are skipped, matching the port's Ctrl handling.
    def ctrl_sequence(keys : Iterable(String)) : String
      keys.compact_map { |key| ctrl_byte(key) }.join
    end

    private def ctrl_byte(key : String) : String?
      lowered = key.downcase
      return nil if lowered == "shift" || lowered == "alt"
      return CTRL_SEQUENCES[lowered] if CTRL_SEQUENCES.has_key?(lowered)

      if key.size == 1 && key.matches?(/^[A-Za-z]$/)
        (key.downcase[0].ord - 'a'.ord + 1).chr.to_s
      end
    end
  end
end
