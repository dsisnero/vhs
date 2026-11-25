require "../spec_helper"

module Vhs
  # Characterization specs for the upstream syntax.go port. Upstream has no Go
  # tests for Highlight, so the assertions pin the rendered escape sequences.
  describe Highlight do
    it "highlights Set commands by argument kind" do
      Highlight.highlight(Parser::Command.new(Token::SET, "FontSize", "16"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Set")} FontSize #{Vhs::Styles::NUMBER_STYLE.render("16")}")

      Highlight.highlight(Parser::Command.new(Token::SET, "TypingSpeed", "100ms"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Set")} TypingSpeed #{Vhs::Styles::TIME_STYLE.render("100ms")}")

      Highlight.highlight(Parser::Command.new(Token::SET, "Theme", "Catppuccin Mocha"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Set")} Theme #{Vhs::Styles::STRING_STYLE.render("Catppuccin Mocha")}")
    end

    it "joins Env options with an equals sign" do
      Highlight.highlight(Parser::Command.new(Token::ENV, "FOO", "bar"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Env")} FOO=#{Vhs::Styles::STRING_STYLE.render("bar")}")
    end

    it "renders output extensions without styling the option" do
      Highlight.highlight(Parser::Command.new(Token::OUTPUT, ".gif", "test.gif"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Output")} .gif #{Vhs::Styles::STRING_STYLE.render("test.gif")}")
    end

    it "styles Type, Sleep, Ctrl, and regex arguments" do
      Highlight.highlight(Parser::Command.new(Token::TYPE, "", "echo hi"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Type")} #{Vhs::Styles::STRING_STYLE.render("echo hi")}")

      Highlight.highlight(Parser::Command.new(Token::SLEEP, "", "1s"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Sleep")} #{Vhs::Styles::TIME_STYLE.render("1s")}")

      Highlight.highlight(Parser::Command.new(Token::CTRL, "", "C"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Ctrl")} #{Vhs::Styles::COMMAND_STYLE.render("C")}")

      Highlight.highlight(Parser::Command.new(Token::REGEX, "", "foo"), false)
        .should eq("#{Vhs::Styles::COMMAND_STYLE.render("Regex")} #{Vhs::Styles::STRING_STYLE.render("foo")}")
    end

    it "renders Hide and Show entirely faint" do
      Highlight.highlight(Parser::Command.new(Token::HIDE), false)
        .should eq("#{Vhs::Styles::FAINT_STYLE.render("Hide")}")
      Highlight.highlight(Parser::Command.new(Token::SHOW), false)
        .should eq("#{Vhs::Styles::FAINT_STYLE.render("Show")}")
    end

    it "renders faint commands without argument styling" do
      Highlight.highlight(Parser::Command.new(Token::TYPE, "", "echo hi"), true)
        .should eq("#{Vhs::Styles::FAINT_STYLE.render("Type echo hi")}")

      Highlight.highlight(Parser::Command.new(Token::SET, "FontSize", "16"), true)
        .should eq("#{Vhs::Styles::FAINT_STYLE.render("Set FontSize 16")}")
    end

    it "prefixes sourced commands with the elided tape path" do
      command = Parser::Command.new(Token::SLEEP, "", "1s")
      command.source = "/tmp/foo.tape"
      Highlight.highlight(command, false)
        .should eq("#{Vhs::Styles::GRAY_STYLE.render("/tmp/foo:")} #{Vhs::Styles::COMMAND_STYLE.render("Sleep")} #{Vhs::Styles::TIME_STYLE.render("1s")}")

      command.source = "/very/long/path.tape"
      Highlight.highlight(command, false).should start_with("#{Vhs::Styles::GRAY_STYLE.render("/very/lon…:")}")
    end

    it "measures the source path in terminal cells" do
      # Double-width characters count as two cells, like go-runewidth.
      command = Parser::Command.new(Token::SLEEP, "", "1s")
      command.source = "/日本語/テスト.tape"
      prefix = Highlight.highlight(command, false)
      prefix.should contain("…:")
      # The path is elided to ten cells including the ellipsis.
      prefix.scan(/\e\[90m([^\e]*)\e\[0m/) do |match|
        match[1].size.should be <= 11 # 10 cells plus the trailing colon
      end
    end

    it "recognizes numbers and times like upstream" do
      Highlight.number?("42").should be_true
      Highlight.number?("4.2").should be_false
      Highlight.time?("100ms").should be_true
      Highlight.time?("2s").should be_true
      # Upstream's regex is ^[0-9]+m?s$, so a bare minute ("1m") is not a time.
      Highlight.time?("1m").should be_false
      Highlight.time?("0.5s").should be_false
    end
  end
end
