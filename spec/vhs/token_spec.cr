require "../spec_helper"

module Vhs
  describe Token do
    it "defines token type constants" do
      # Check a few constants
      Token::AT.should eq(:"@")
      Token::EQUAL.should eq(:"=")
      Token::EOF.should eq(:EOF)
      Token::SET.should eq(:SET)
      Token::OUTPUT.should eq(:OUTPUT)
    end

    describe ".setting?" do
      it "returns true for setting tokens" do
        Token.setting?(Token::FONT_SIZE).should be_true
        Token.setting?(Token::WIDTH).should be_true
        Token.setting?(Token::HEIGHT).should be_true
        Token.setting?(Token::SHELL).should be_true
        Token.setting?(Token::THEME).should be_true
      end

      it "returns false for non-setting tokens" do
        Token.setting?(Token::AT).should be_false
        Token.setting?(Token::EOF).should be_false
        Token.setting?(Token::TYPE).should be_false
      end
    end

    describe ".command?" do
      it "returns true for command tokens" do
        Token.command?(Token::TYPE).should be_true
        Token.command?(Token::SLEEP).should be_true
        Token.command?(Token::ENTER).should be_true
        Token.command?(Token::BACKSPACE).should be_true
        Token.command?(Token::UP).should be_true
        Token.command?(Token::DOWN).should be_true
      end

      it "returns false for non-command tokens" do
        Token.command?(Token::AT).should be_false
        Token.command?(Token::EOF).should be_false
        Token.command?(Token::FONT_SIZE).should be_false
      end
    end

    describe ".modifier?" do
      it "returns true for modifier tokens" do
        Token.modifier?(Token::ALT).should be_true
        Token.modifier?(Token::SHIFT).should be_true
      end

      it "returns false for non-modifier tokens" do
        Token.modifier?(Token::CTRL).should be_false
        Token.modifier?(Token::ENTER).should be_false
      end
    end

    describe ".to_camel" do
      it "converts snake_case to CamelCase" do
        Token.to_camel("font_size").should eq("FontSize")
        Token.to_camel("wait_timeout").should eq("WaitTimeout")
        Token.to_camel("hello_world").should eq("HelloWorld")
        Token.to_camel("single").should eq("Single")
        Token.to_camel("").should eq("")
      end
    end

    describe ".lookup_identifier" do
      it "returns keyword token for known identifiers" do
        Token.lookup_identifier("Set").should eq(Token::SET)
        Token.lookup_identifier("Sleep").should eq(Token::SLEEP)
        Token.lookup_identifier("FontSize").should eq(Token::FONT_SIZE)
        Token.lookup_identifier("true").should eq(Token::BOOLEAN)
        Token.lookup_identifier("false").should eq(Token::BOOLEAN)
      end

      it "returns STRING token for unknown identifiers" do
        Token.lookup_identifier("Unknown").should eq(Token::STRING)
        Token.lookup_identifier("custom").should eq(Token::STRING)
      end
    end

    describe ".to_human_readable" do
      it "converts command tokens to CamelCase" do
        Token.to_human_readable(Token::TYPE).should eq("Type")
        Token.to_human_readable(Token::SLEEP).should eq("Sleep")
      end

      it "converts setting tokens to CamelCase" do
        Token.to_human_readable(Token::FONT_SIZE).should eq("FontSize")
        Token.to_human_readable(Token::WIDTH).should eq("Width")
      end

      it "returns string representation for other tokens" do
        Token.to_human_readable(Token::AT).should eq("@")
        Token.to_human_readable(Token::EOF).should eq("EOF")
      end
    end

    describe "Token struct" do
      it "creates tokens with correct attributes" do
        token = Token::Token.new(Token::SET, "Set", 1, 5)
        token.type.should eq(Token::SET)
        token.literal.should eq("Set")
        token.line.should eq(1)
        token.column.should eq(5)
      end

      it "has a string representation" do
        token = Token::Token.new(Token::TYPE, "Type", 2, 3)
        token.to_s.should contain("type=TYPE")
        token.to_s.should contain("literal=\"Type\"")
        token.to_s.should contain("line=2")
        token.to_s.should contain("column=3")
      end
    end
  end
end
