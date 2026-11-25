module Vhs
  # Syntax highlighting for the command echo, ported from upstream syntax.go.
  #
  # Styles come from src/vhs/styles.cr, which uses the same lipgloss model as
  # upstream syntax.go (NoneStyle and KeywordStyle carry no attributes).
  module Highlight
    extend self

    # How many characters of a sourced tape path are shown before it is elided.
    SOURCE_DISPLAY_MAX_LENGTH = 10

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
      return paint(Styles::FAINT_STYLE, type_name(c)) if c.type == Token::HIDE || c.type == Token::SHOW

      options_style, args_style = styles_for(c)

      rendered = String::Builder.new
      rendered << source_prefix(c)
      rendered << paint(Styles::COMMAND_STYLE, type_name(c)) << " "
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
      "#{source_prefix(c)}#{Styles::FAINT_STYLE.render(command)}"
    end

    private def styles_for(c : Parser::Command) : {Lipgloss::Style, Lipgloss::Style}
      case c.type
      when Token::REGEX
        {Styles::TIME_STYLE, Styles::STRING_STYLE}
      when Token::SET
        {Styles::KEYWORD_STYLE, set_arg_style(c.args)}
      when Token::ENV, Token::OUTPUT
        {Styles::NONE_STYLE, Styles::STRING_STYLE}
      when Token::CTRL
        {Styles::TIME_STYLE, Styles::COMMAND_STYLE}
      when Token::SLEEP
        {Styles::TIME_STYLE, Styles::TIME_STYLE}
      when Token::TYPE
        {Styles::TIME_STYLE, Styles::STRING_STYLE}
      else
        {Styles::TIME_STYLE, Styles::NUMBER_STYLE}
      end
    end

    private def set_arg_style(args : String) : Lipgloss::Style
      return Styles::NUMBER_STYLE if number?(args)
      return Styles::TIME_STYLE if time?(args)

      Styles::STRING_STYLE
    end

    # Upstream's CommandType.String: the token name through ToCamel.
    private def type_name(c : Parser::Command) : String
      Token.to_camel(c.type.to_s)
    end

    private def source_prefix(c : Parser::Command) : String
      return "" if c.source.empty?

      display_path = truncate(trim_extension(c.source), SOURCE_DISPLAY_MAX_LENGTH)
      "#{Styles::GRAY_STYLE.render("#{display_path}:")} "
    end

    private def paint(style : Lipgloss::Style, text : String) : String
      style.render(text)
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
