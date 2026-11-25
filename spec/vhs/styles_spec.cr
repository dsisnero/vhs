require "../spec_helper"

module Vhs
  # Characterization specs for the upstream style.go port. Upstream defines these
  # with lipgloss; so does the port, through the dsisnero/lipgloss shard.
  describe Styles do
    around_each do |example|
      original = Lipgloss::StyleRenderer.default.color_profile
      begin
        example.run
      ensure
        Lipgloss::StyleRenderer.default.color_profile = original
      end
    end

    it "defines the syntax styles with upstream's colours" do
      Lipgloss::StyleRenderer.default.color_profile = Lipgloss::ColorProfile::ANSI

      Styles::COMMAND_STYLE.render("Set").should eq("\e[94mSet\e[0m")
      Styles::NUMBER_STYLE.render("1").should eq("\e[33m1\e[0m")
      Styles::STRING_STYLE.render("s").should eq("\e[92ms\e[0m")
      Styles::TIME_STYLE.render("1s").should eq("\e[93m1s\e[0m")
      Styles::URL_STYLE.render("u").should eq("\e[33mu\e[0m")
      Styles::GRAY_STYLE.render("g").should eq("\e[90mg\e[0m")
      Styles::LINE_NUMBER_STYLE.render(" 1 │ ").should eq("\e[90m 1 │ \e[0m")
      Styles::ERROR_STYLE.render("e").should eq("\e[31me\e[0m")
    end

    it "keeps NoneStyle and KeywordStyle attribute-free like upstream" do
      Styles::NONE_STYLE.render("plain").should eq("plain")
      Styles::KEYWORD_STYLE.render("plain").should eq("plain")
    end

    it "renders the faint style with the adaptive colour" do
      Lipgloss::StyleRenderer.default.color_profile = Lipgloss::ColorProfile::ANSI

      # The renderer reports a dark background by default, so the dark variant
      # (238) applies, which ANSI maps to bright black.
      Styles::FAINT_STYLE.render("Hide").should eq("\e[90mHide\e[0m")
    end

    it "frames the error file style with a border, padding, and the default width" do
      rendered = Styles::ERROR_FILE_STYLE.render("demo.tape")
      lines = rendered.lines

      lines.size.should be >= 3
      lines.first.should contain("┌")
      lines.last.should contain("└")
      rendered.should contain("demo.tape")
    end

    describe ".detect_profile" do
      it "honours NO_COLOR" do
        Styles.detect_profile({"NO_COLOR" => "1", "COLORTERM" => "truecolor"} of String => String)
          .should eq(Lipgloss::ColorProfile::ASCII)
      end

      it "detects truecolor from COLORTERM" do
        Styles.detect_profile({"COLORTERM" => "truecolor"} of String => String)
          .should eq(Lipgloss::ColorProfile::TrueColor)
        Styles.detect_profile({"COLORTERM" => "24bit"} of String => String)
          .should eq(Lipgloss::ColorProfile::ANSI)
      end

      it "detects a 256-colour terminal from TERM" do
        Styles.detect_profile({"TERM" => "xterm-256color"} of String => String)
          .should eq(Lipgloss::ColorProfile::ANSI256)
      end

      it "falls back to the ANSI palette" do
        Styles.detect_profile({"TERM" => "xterm"} of String => String)
          .should eq(Lipgloss::ColorProfile::ANSI)
      end
    end

    describe ".configure" do
      it "applies the detected profile to the shared renderer" do
        Styles.configure({"TERM" => "screen-256color"} of String => String)
        Lipgloss::StyleRenderer.default.color_profile.should eq(Lipgloss::ColorProfile::ANSI256)
      end
    end
  end
end
