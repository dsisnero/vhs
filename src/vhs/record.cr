require "./token"

module Vhs
  # sleep_threshold is the time at which if there has been no activity in the
  # tape file we insert a Sleep command.
  SLEEP_THRESHOLD = 500.milliseconds

  private CURSOR_RESPONSE = /\x1b\[\d+;\d+R/
  private OSC_RESPONSE    = /\x1b\]\d+;rgb:....\/....\/....(\x07|\x1b\\)/

  # EscapeSequences is a map of escape sequences to their VHS commands.
  ESCAPE_SEQUENCES = {
    "\x1b[A"  => "UP",
    "\x1b[B"  => "DOWN",
    "\x1b[C"  => "RIGHT",
    "\x1b[D"  => "LEFT",
    "\x1b[1~" => "HOME",
    "\x1b[2~" => "INSERT",
    "\x1b[3~" => "DELETE",
    "\x1b[4~" => "END",
    "\x1b[5~" => "PAGE_UP",
    "\x1b[6~" => "PAGE_DOWN",
    "\x01"    => "CTRL+A",
    "\x02"    => "CTRL+B",
    "\x03"    => "CTRL+C",
    "\x04"    => "CTRL+D",
    "\x05"    => "CTRL+E",
    "\x06"    => "CTRL+F",
    "\x07"    => "CTRL+G",
    "\x08"    => "BACKSPACE",
    "\x09"    => "TAB",
    "\x0b"    => "CTRL+K",
    "\x0c"    => "CTRL+L",
    "\x0d"    => "ENTER",
    "\x0e"    => "CTRL+N",
    "\x0f"    => "CTRL+O",
    "\x10"    => "CTRL+P",
    "\x11"    => "CTRL+Q",
    "\x12"    => "CTRL+R",
    "\x13"    => "CTRL+S",
    "\x14"    => "CTRL+T",
    "\x15"    => "CTRL+U",
    "\x16"    => "CTRL+V",
    "\x17"    => "CTRL+W",
    "\x18"    => "CTRL+X",
    "\x19"    => "CTRL+Y",
    "\x1a"    => "CTRL+Z",
    "\x1b"    => "ESCAPE",
    "\x7f"    => "BACKSPACE",
  }

  # quote wraps a string in (single or double) quotes.
  private def self.quote(s : String) : String
    if s.includes?('"') && s.includes?('\'')
      "`#{s}`"
    elsif s.includes?('"')
      "'#{s}'"
    else
      "\"#{s}\""
    end
  end

  # token_type returns the Token::Type for a command string.
  private def self.token_type(s : String) : Token::Type
    # Convert snake_case to CamelCase for KEYWORDS lookup
    # Examples: "UP" -> "Up", "PAGE_UP" -> "PageUp", "CTRL+A" -> "Ctrl+a" (not a keyword)
    camel = Token.to_camel(s.downcase)
    Token.lookup_identifier(camel)
  end

  # command? returns whether the string is a command.
  private def self.command?(s : String) : Bool
    return false if s.empty?
    # CTRL+ and ALT+ prefixes are handled separately
    if s.starts_with?("CTRL") || s.starts_with?("ALT") || s.starts_with?("SET")
      return false
    end
    Token.command?(token_type(s))
  end

  # format_sleep formats a sleep duration like Go's time.Duration String()
  # but with the simplification: if duration >= 1 minute, use seconds with "s"
  # else if duration.seconds >= 1, use seconds with "s" (no decimal if integer)
  # else use milliseconds with "ms"
  private def self.format_sleep(duration : Time::Span) : String
    if duration >= 1.minute
      seconds = duration.total_seconds
      # Remove trailing .0 if integer
      seconds_str = seconds.to_s.gsub(/\.0$/, "")
      "Sleep #{seconds_str}s"
    elsif duration.seconds >= 1
      seconds = duration.total_seconds
      seconds_str = seconds.to_s.gsub(/\.0$/, "")
      "Sleep #{seconds_str}s"
    else
      "Sleep #{duration.total_milliseconds.to_i}ms"
    end
  end

  # input_to_tape takes input from a PTY stdin and converts it into a tape file.
  def self.input_to_tape(input : String) : String
    # If the user exited the shell by typing exit don't record this in the
    # command.
    #
    # NOTE: this is not very robust as if someone types exii<BS>t it will not work
    # correctly and the exit will show up. In this case, the user should edit the
    # tape file.
    s = input.strip.rchop("exit")

    # Remove cursor / osc responses
    s = s.gsub(CURSOR_RESPONSE, "")
    s = s.gsub(OSC_RESPONSE, "")

    # Substitute escape sequences for commands
    ESCAPE_SEQUENCES.each do |sequence, command|
      s = s.gsub(sequence, "\n#{command}\n")
    end

    s = s.gsub("\n\n", "\n")

    sanitized = String::Builder.new
    lines = s.split("\n", remove_empty: false)

    i = 0
    while i < lines.size - 1
      # Group repeated commands to compress file and make it more readable.
      repeat = 1
      while lines[i] == lines[i + repeat]
        repeat += 1
        break if i + repeat == lines.size
      end
      i += repeat - 1

      line = lines[i]

      # We've encountered some non-command, assume that we need to type these
      # characters.
      if line == "SLEEP"
        sleep_duration = SLEEP_THRESHOLD * repeat
        sanitized << format_sleep(sleep_duration)
      elsif line.starts_with?("CTRL")
        repeat.times do
          sanitized << "Ctrl" + line.lchop("CTRL")
          sanitized << "\n"
        end
        i += 1
        next
      elsif line.starts_with?("ALT")
        repeat.times do
          sanitized << "Alt" + line.lchop("ALT")
          sanitized << "\n"
        end
        i += 1
        next
      elsif line.starts_with?("SET")
        sanitized << "Set" + line.lchop("SET")
      elsif command?(line)
        token_type = token_type(line)
        sanitized << Token.to_human_readable(token_type)
        if repeat > 1
          sanitized << " " + repeat.to_s
        end
      else
        if !line.empty?
          sanitized << "Type " + quote(line)
          sanitized << "\n"
        end
        i += 1
        next
      end
      sanitized << "\n"
      i += 1
    end

    sanitized.to_s
  end
end
