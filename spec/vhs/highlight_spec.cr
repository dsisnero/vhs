require "../spec_helper"

module Vhs
  # Characterization specs for the upstream syntax.go port. Upstream has no Go
  # tests for Highlight, so the assertions pin the rendered escape sequences.
  describe Highlight do
    it "highlights Set commands by argument kind" do
      Highlight.highlight(Parser::Command.new(Token::SET, "FontSize", "16"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Set#{STYLE_RESET} FontSize #{Highlight::NUMBER_STYLE}16#{STYLE_RESET}")

      Highlight.highlight(Parser::Command.new(Token::SET, "TypingSpeed", "100ms"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Set#{STYLE_RESET} TypingSpeed #{Highlight::TIME_STYLE}100ms#{STYLE_RESET}")

      Highlight.highlight(Parser::Command.new(Token::SET, "Theme", "Catppuccin Mocha"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Set#{STYLE_RESET} Theme #{Highlight::STRING_STYLE}Catppuccin Mocha#{STYLE_RESET}")
    end

    it "joins Env options with an equals sign" do
      Highlight.highlight(Parser::Command.new(Token::ENV, "FOO", "bar"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Env#{STYLE_RESET} FOO=#{Highlight::STRING_STYLE}bar#{STYLE_RESET}")
    end

    it "renders output extensions without styling the option" do
      Highlight.highlight(Parser::Command.new(Token::OUTPUT, ".gif", "test.gif"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Output#{STYLE_RESET} .gif #{Highlight::STRING_STYLE}test.gif#{STYLE_RESET}")
    end

    it "styles Type, Sleep, Ctrl, and regex arguments" do
      Highlight.highlight(Parser::Command.new(Token::TYPE, "", "echo hi"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Type#{STYLE_RESET} #{Highlight::STRING_STYLE}echo hi#{STYLE_RESET}")

      Highlight.highlight(Parser::Command.new(Token::SLEEP, "", "1s"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Sleep#{STYLE_RESET} #{Highlight::TIME_STYLE}1s#{STYLE_RESET}")

      Highlight.highlight(Parser::Command.new(Token::CTRL, "", "C"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Ctrl#{STYLE_RESET} #{Highlight::COMMAND_STYLE}C#{STYLE_RESET}")

      Highlight.highlight(Parser::Command.new(Token::REGEX, "", "foo"), false)
        .should eq("#{Highlight::COMMAND_STYLE}Regex#{STYLE_RESET} #{Highlight::STRING_STYLE}foo#{STYLE_RESET}")
    end

    it "renders Hide and Show entirely faint" do
      Highlight.highlight(Parser::Command.new(Token::HIDE), false)
        .should eq("#{Highlight::FAINT_STYLE}Hide#{STYLE_RESET}")
      Highlight.highlight(Parser::Command.new(Token::SHOW), false)
        .should eq("#{Highlight::FAINT_STYLE}Show#{STYLE_RESET}")
    end

    it "renders faint commands without argument styling" do
      Highlight.highlight(Parser::Command.new(Token::TYPE, "", "echo hi"), true)
        .should eq("#{Highlight::FAINT_STYLE}Type echo hi#{STYLE_RESET}")

      Highlight.highlight(Parser::Command.new(Token::SET, "FontSize", "16"), true)
        .should eq("#{Highlight::FAINT_STYLE}Set FontSize 16#{STYLE_RESET}")
    end

    it "prefixes sourced commands with the elided tape path" do
      command = Parser::Command.new(Token::SLEEP, "", "1s")
      command.source = "/tmp/foo.tape"
      Highlight.highlight(command, false)
        .should eq("#{Highlight::GRAY_STYLE}/tmp/foo:#{STYLE_RESET} #{Highlight::COMMAND_STYLE}Sleep#{STYLE_RESET} #{Highlight::TIME_STYLE}1s#{STYLE_RESET}")

      command.source = "/very/long/path.tape"
      Highlight.highlight(command, false).should start_with("#{Highlight::GRAY_STYLE}/very/lon…:#{STYLE_RESET}")
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
