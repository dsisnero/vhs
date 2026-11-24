require "../spec_helper"

module Vhs
  # Upstream vhs/style.go has no Go test file; these are characterization specs
  # pinning the theme constants and DefaultStyleOptions to upstream values.
  describe "style" do
    describe "theme colors" do
      it "matches upstream vhs/style.go" do
        BACKGROUND.should eq("#171717")
        FOREGROUND.should eq("#dddddd")
        BLACK.should eq("#282a2e")
        BRIGHT_BLACK.should eq("#4d4d4d")
        RED.should eq("#D74E6F")
        BRIGHT_RED.should eq("#FE5F86")
        GREEN.should eq("#31BB71")
        BRIGHT_GREEN.should eq("#00D787")
        YELLOW.should eq("#D3E561")
        BRIGHT_YELLOW.should eq("#EBFF71")
        BLUE.should eq("#8056FF")
        BRIGHT_BLUE.should eq("#9B79FF")
        MAGENTA.should eq("#ED61D7")
        BRIGHT_MAGENTA.should eq("#FF7AEA")
        CYAN.should eq("#04D7D7")
        BRIGHT_CYAN.should eq("#00FEFE")
        WHITE.should eq("#bfbfbf")
        BRIGHT_WHITE.should eq("#e6e6e6")
        INDIGO.should eq("#5B56E0")
      end

      it "wires the theme colors into the default theme" do
        DEFAULT_THEME.background.should eq(BACKGROUND)
        DEFAULT_THEME.foreground.should eq(FOREGROUND)
        DEFAULT_THEME.black.should eq(BLACK)
        DEFAULT_THEME.bright_black.should eq(BRIGHT_BLACK)
        DEFAULT_THEME.red.should eq(RED)
        DEFAULT_THEME.bright_red.should eq(BRIGHT_RED)
        DEFAULT_THEME.green.should eq(GREEN)
        DEFAULT_THEME.bright_green.should eq(BRIGHT_GREEN)
        DEFAULT_THEME.yellow.should eq(YELLOW)
        DEFAULT_THEME.bright_yellow.should eq(BRIGHT_YELLOW)
        DEFAULT_THEME.blue.should eq(BLUE)
        DEFAULT_THEME.bright_blue.should eq(BRIGHT_BLUE)
        DEFAULT_THEME.magenta.should eq(MAGENTA)
        DEFAULT_THEME.bright_magenta.should eq(BRIGHT_MAGENTA)
        DEFAULT_THEME.cyan.should eq(CYAN)
        DEFAULT_THEME.bright_cyan.should eq(BRIGHT_CYAN)
        DEFAULT_THEME.white.should eq(WHITE)
        DEFAULT_THEME.bright_white.should eq(BRIGHT_WHITE)
      end
    end

    describe ".default_style_options" do
      it "matches upstream DefaultStyleOptions" do
        style = Vhs.default_style_options

        style.width.should eq(1200)
        style.height.should eq(600)
        style.padding.should eq(60)
        style.margin_fill.should eq(DEFAULT_THEME.background)
        style.margin.should eq(0)
        style.window_bar.should eq("")
        style.window_bar_size.should eq(30)
        style.window_bar_color.should eq(DEFAULT_THEME.background)
        style.border_radius.should eq(0)
        style.background_color.should eq(DEFAULT_THEME.background)
      end

      it "uses the upstream default dimensions" do
        Vhs.default_style_options.width.should eq(DEFAULT_WIDTH)
        Vhs.default_style_options.height.should eq(DEFAULT_HEIGHT)
        Vhs.default_style_options.padding.should eq(DEFAULT_PADDING)
        Vhs.default_style_options.window_bar_size.should eq(DEFAULT_WINDOW_BAR_SIZE)
      end
    end
  end
end
