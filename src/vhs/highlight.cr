module Vhs
  # Syntax highlighting for the command echo, ported from upstream syntax.go.
  #
  # Upstream renders these through lipgloss styles; the port emits the 16-color
  # ANSI codes those styles resolve to, and an empty string where the style has
  # no attributes (NoneStyle, KeywordStyle).
  module Highlight
    extend self

    # How many characters of a sourced tape path are shown before it is elided.
    SOURCE_DISPLAY_MAX_LENGTH = 10

    COMMAND_STYLE = "\e[94m" # lipgloss.Color("12")
    FAINT_STYLE   = "\e[2m"  # lipgloss AdaptiveColor{Light: "242", Dark: "238"}
    NUMBER_STYLE  = "\e[33m" # lipgloss.Color("3")
    STRING_STYLE  = "\e[92m" # lipgloss.Color("10")
    TIME_STYLE    = "\e[93m" # lipgloss.Color("11")
    GRAY_STYLE    = "\e[90m" # lipgloss.Color("8")
    NONE_STYLE    = ""
    KEYWORD_STYLE = ""

    NUMBER_REGEX = /^[0-9]+$/
    TIME_REGEX   = /^[0-9]+m?s$/

    def number?(s : String) : Bool
      NUMBER_REGEX.matches?(s)
    end

    def time?(s : String) : Bool
      TIME_REGEX.matches?(s)
    end

    # Highlights a command for prettier printing. `faint` dims hidden commands.
    def highlight(c : Parser::Command, faint : Bool) : String
      return faint_command(c) if faint
      return paint(FAINT_STYLE, type_name(c)) if c.type == Token::HIDE || c.type == Token::SHOW

      options_style, args_style = styles_for(c)

      rendered = String::Builder.new
      rendered << source_prefix(c)
      rendered << paint(COMMAND_STYLE, type_name(c)) << " "
      unless c.options.empty?
        rendered << paint(options_style, c.options)
        rendered << (c.type == Token::ENV ? "=" : " ")
      end
      rendered << paint(args_style, c.args)
      rendered.to_s
    end

    private def faint_command(c : Parser::Command) : String
      command = if c.options.empty?
                  "#{type_name(c)} #{c.args}"
                else
                  "#{type_name(c)} #{c.options} #{c.args}"
                end
      "#{source_prefix(c)}#{FAINT_STYLE}#{command}#{STYLE_RESET}"
    end

    private def styles_for(c : Parser::Command) : {String, String}
      case c.type
      when Token::REGEX
        {TIME_STYLE, STRING_STYLE}
      when Token::SET
        {KEYWORD_STYLE, set_arg_style(c.args)}
      when Token::ENV, Token::OUTPUT
        {NONE_STYLE, STRING_STYLE}
      when Token::CTRL
        {TIME_STYLE, COMMAND_STYLE}
      when Token::SLEEP
        {TIME_STYLE, TIME_STYLE}
      when Token::TYPE
        {TIME_STYLE, STRING_STYLE}
      else
        {TIME_STYLE, NUMBER_STYLE}
      end
    end

    private def set_arg_style(args : String) : String
      return NUMBER_STYLE if number?(args)
      return TIME_STYLE if time?(args)

      STRING_STYLE
    end

    # Upstream's CommandType.String: the token name through ToCamel.
    private def type_name(c : Parser::Command) : String
      Token.to_camel(c.type.to_s)
    end

    private def source_prefix(c : Parser::Command) : String
      return "" if c.source.empty?

      display_path = truncate(trim_extension(c.source), SOURCE_DISPLAY_MAX_LENGTH)
      "#{GRAY_STYLE}#{display_path}:#{STYLE_RESET} "
    end

    private def paint(style : String, text : String) : String
      return text if style.empty?

      "#{style}#{text}#{STYLE_RESET}"
    end

    private def trim_extension(path : String) : String
      path.ends_with?(".tape") ? path[0...-".tape".size] : path
    end

    # Truncates to `max` characters, appending an ellipsis when cut. Upstream uses
    # go-runewidth, which accounts for double-width characters; the port counts
    # characters, which matches for the ASCII paths it is meant for.
    private def truncate(text : String, max : Int32) : String
      return text if text.size <= max

      # go-runewidth's Truncate counts the tail against the budget.
      "#{text[0, max - 1]}…"
    end
  end
end
