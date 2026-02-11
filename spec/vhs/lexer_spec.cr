require "../spec_helper"

module Vhs
  describe Lexer do
    describe "#next_token" do
      it "tokenizes basic symbols" do
        lexer = Lexer.new("@ = ] [ - % ^ \\ # + { ` ' \" /")
        tokens = [] of Token::Token
        14.times { tokens << lexer.next_token }

        tokens[0].type.should eq(Token::AT)
        tokens[1].type.should eq(Token::EQUAL)
        tokens[2].type.should eq(Token::RIGHT_BRACKET)
        tokens[3].type.should eq(Token::LEFT_BRACKET)
        tokens[4].type.should eq(Token::MINUS)
        tokens[5].type.should eq(Token::PERCENT)
        tokens[6].type.should eq(Token::CARET)
        tokens[7].type.should eq(Token::BACKSLASH)
        tokens[8].type.should eq(Token::COMMENT)
        tokens[8].literal.should eq(" + { ` ' \" /")
        # After comment consumes until EOF, remaining tokens are EOF
        tokens[9].type.should eq(Token::EOF)
        tokens[10].type.should eq(Token::EOF)
        tokens[11].type.should eq(Token::EOF)
        tokens[12].type.should eq(Token::EOF)
        tokens[13].type.should eq(Token::EOF)
      end

      it "tokenizes numbers" do
        lexer = Lexer.new("123 45.6 0.123")
        tokens = [] of Token::Token
        3.times { tokens << lexer.next_token }

        tokens[0].type.should eq(Token::NUMBER)
        tokens[0].literal.should eq("123")
        tokens[1].type.should eq(Token::NUMBER)
        tokens[1].literal.should eq("45.6")
        tokens[2].type.should eq(Token::NUMBER)
        tokens[2].literal.should eq("0.123")
      end

      it "tokenizes identifiers and keywords" do
        lexer = Lexer.new("Set Sleep Type Enter FontSize true false")
        tokens = [] of Token::Token
        7.times { tokens << lexer.next_token }

        tokens[0].type.should eq(Token::SET)
        tokens[0].literal.should eq("Set")
        tokens[1].type.should eq(Token::SLEEP)
        tokens[2].type.should eq(Token::TYPE)
        tokens[3].type.should eq(Token::ENTER)
        tokens[4].type.should eq(Token::FONT_SIZE)
        tokens[5].type.should eq(Token::BOOLEAN)
        tokens[5].literal.should eq("true")
        tokens[6].type.should eq(Token::BOOLEAN)
        tokens[6].literal.should eq("false")
      end

      it "tokenizes strings with different delimiters" do
        lexer = Lexer.new("\"hello\" 'world' `test`")
        tokens = [] of Token::Token
        3.times { tokens << lexer.next_token }

        tokens[0].type.should eq(Token::STRING)
        tokens[0].literal.should eq("hello")
        tokens[1].type.should eq(Token::STRING)
        tokens[1].literal.should eq("world")
        tokens[2].type.should eq(Token::STRING)
        tokens[2].literal.should eq("test")
      end

      it "tokenizes comments" do
        lexer = Lexer.new("# This is a comment")
        token = lexer.next_token
        token.type.should eq(Token::COMMENT)
        token.literal.should eq(" This is a comment")
      end

      it "tokenizes JSON objects" do
        lexer = Lexer.new(%({"key": "value"}))
        token = lexer.next_token
        token.type.should eq(Token::JSON)
        token.literal.should eq(%({"key": "value"}))
      end

      it "tokenizes regex patterns" do
        lexer = Lexer.new("/pattern/")
        token = lexer.next_token
        token.type.should eq(Token::REGEX)
        token.literal.should eq("pattern")
      end

      it "tokenizes regex with escaped delimiters" do
        lexer = Lexer.new("/foo\\/bar/")
        token = lexer.next_token
        token.type.should eq(Token::REGEX)
        token.literal.should eq("foo\\/bar")
      end

      it "handles EOF" do
        lexer = Lexer.new("")
        token = lexer.next_token
        token.type.should eq(Token::EOF)
        token.literal.should eq("\0")
      end

      it "tracks line and column numbers" do
        input = "        Set FontSize 16\n        Output test.gif"
        lexer = Lexer.new(input)

        token1 = lexer.next_token
        token1.type.should eq(Token::SET)
        token1.line.should eq(1)
        token1.column.should eq(9) # "Set" starts at column 9 (8 spaces + 1)

        token2 = lexer.next_token
        token2.type.should eq(Token::FONT_SIZE)
        token2.line.should eq(1)

        token3 = lexer.next_token
        token3.type.should eq(Token::NUMBER)
        token3.literal.should eq("16")

        token4 = lexer.next_token
        token4.type.should eq(Token::OUTPUT)
        token4.line.should eq(2)
      end

      it "tokenizes a simple tape file" do
        input = <<-TAPE
        Output demo.gif
        Set FontSize 16
        Set Width 800
        Type "Hello VHS"
        Enter
        Sleep 1s
        TAPE

        lexer = Lexer.new(input)
        tokens = [] of Token::Token
        12.times { tokens << lexer.next_token }

        expected_types = [
          Token::OUTPUT,
          Token::STRING, # "demo.gif"
          Token::SET,
          Token::FONT_SIZE,
          Token::NUMBER, # 16
          Token::SET,
          Token::WIDTH,
          Token::NUMBER, # 800
          Token::TYPE,
          Token::STRING, # "Hello VHS"
          Token::ENTER,
          Token::SLEEP,
          # Note: "1s" will be tokenized as NUMBER then SECONDS
          # but we're only taking 12 tokens
        ]

        tokens.map(&.type).should eq(expected_types)
      end
    end
  end
end
