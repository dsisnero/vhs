require "lipgloss"

module Vhs
  # Styles for syntax highlighting, ported from upstream style.go.
  #
  # Upstream builds these with charmbracelet/lipgloss; the port uses the
  # dsisnero/lipgloss shard, so the colour codes come from the same style model
  # and the same colour-profile negotiation instead of hand-written escapes.
  module Styles
    extend self

    # Upstream `lipgloss.Color("12")`, `"3"`, `"10"`, `"11"`, `"8"`, `"1"`.
    COMMAND_STYLE = Lipgloss.new_style.foreground(Lipgloss::Color.indexed(12))
    FAINT_STYLE   = Lipgloss.new_style.foreground(
      Lipgloss::AdaptiveColor.new(Lipgloss::Color.indexed(242), Lipgloss::Color.indexed(238))
    )
    NONE_STYLE        = Lipgloss.new_style
    KEYWORD_STYLE     = Lipgloss.new_style
    URL_STYLE         = Lipgloss.new_style.foreground(Lipgloss::Color.indexed(3))
    NUMBER_STYLE      = Lipgloss.new_style.foreground(Lipgloss::Color.indexed(3))
    STRING_STYLE      = Lipgloss.new_style.foreground(Lipgloss::Color.indexed(10))
    TIME_STYLE        = Lipgloss.new_style.foreground(Lipgloss::Color.indexed(11))
    LINE_NUMBER_STYLE = Lipgloss.new_style.foreground(Lipgloss::Color.indexed(8))
    ERROR_STYLE       = Lipgloss.new_style.foreground(Lipgloss::Color.indexed(1))
    GRAY_STYLE        = Lipgloss.new_style.foreground(Lipgloss::Color.indexed(8))

    # ErrorFileStyle frames the file name in error reports. It keeps upstream's
    # width of the default column count.
    ERROR_FILE_STYLE = Lipgloss.new_style
      .border(Lipgloss::Border.normal)
      .border_foreground(Lipgloss::Color.indexed(8))
      .foreground(Lipgloss::Color.indexed(1))
      .padding(0, 1)
      .width(DEFAULT_COLUMNS)

    # detect_profile picks the colour profile the way termenv does for lipgloss:
    # NO_COLOR disables colour, COLORTERM=truecolor enables 24-bit, and a TERM
    # advertising 256 colours gets the 256-colour palette. Everything else falls
    # back to the 16-colour ANSI palette.
    def detect_profile(env = ENV) : Lipgloss::ColorProfile
      return Lipgloss::ColorProfile::ASCII if env["NO_COLOR"]?

      color_term = env["COLORTERM"]?
      if color_term && color_term.downcase.includes?("truecolor")
        return Lipgloss::ColorProfile::TrueColor
      end

      term = env["TERM"]? || ""
      return Lipgloss::ColorProfile::ANSI256 if term.includes?("256")

      Lipgloss::ColorProfile::ANSI
    end

    # configure applies the detected profile to the shared style renderer.
    def configure(env = ENV) : Nil
      Lipgloss::StyleRenderer.default.color_profile = detect_profile(env)
    end
  end
end
