require "../spec_helper"

module Vhs
  describe Parser do
    describe "#parse" do
      it "parses a simple SET command" do
        lexer = Lexer.new("Set FontSize 16")
        parser = Parser.new(lexer)
        commands = parser.parse
        commands.size.should eq(1)
        cmd = commands[0]
        cmd.type.should eq(Token::SET)
        cmd.options.should eq("FontSize")
        cmd.args.should eq("16")
      end

      it "parses multiple SET commands" do
        lexer = Lexer.new("Set FontSize 16\nSet Width 800")
        parser = Parser.new(lexer)
        commands = parser.parse
        commands.size.should eq(2)
        commands[0].type.should eq(Token::SET)
        commands[0].options.should eq("FontSize")
        commands[0].args.should eq("16")
        commands[1].type.should eq(Token::SET)
        commands[1].options.should eq("Width")
        commands[1].args.should eq("800")
      end

      it "skips comments" do
        lexer = Lexer.new("# Comment\nSet FontSize 16")
        parser = Parser.new(lexer)
        commands = parser.parse
        commands.size.should eq(1)
        commands[0].options.should eq("FontSize")
      end

      it "parses SET TypingSpeed with units" do
        lexer = Lexer.new("Set TypingSpeed 100ms")
        parser = Parser.new(lexer)
        commands = parser.parse
        commands.size.should eq(1)
        cmd = commands[0]
        cmd.options.should eq("TypingSpeed")
        cmd.args.should eq("100ms")
      end
    end
  end
end
