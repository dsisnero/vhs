require "../spec_helper"

# Token expectations transcribed from vendor/vhs/lexer/lexer_test.go
# (v0.10.0+19), so the Go test tables stay the source of truth.
private def next_token_expectations
  [
    {Vhs::Token::OUTPUT, "Output"},
    {Vhs::Token::STRING, "examples/out.gif"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::FONT_SIZE, "FontSize"},
    {Vhs::Token::NUMBER, "42"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::PADDING, "Padding"},
    {Vhs::Token::NUMBER, "5"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::CURSOR_BLINK, "CursorBlink"},
    {Vhs::Token::BOOLEAN, "false"},
    {Vhs::Token::TYPE, "Type"},
    {Vhs::Token::STRING, "echo 'Hello, world!'"},
    {Vhs::Token::ENTER, "Enter"},
    {Vhs::Token::TYPE, "Type"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, ".1"},
    {Vhs::Token::STRING, "echo 'Hello, world!'"},
    {Vhs::Token::LEFT, "Left"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::RIGHT, "Right"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "100"},
    {Vhs::Token::MILLISECONDS, "ms"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, "500"},
    {Vhs::Token::MILLISECONDS, "ms"},
    {Vhs::Token::CTRL, "Ctrl"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "C"},
    {Vhs::Token::ENTER, "Enter"},
    {Vhs::Token::CTRL, "Ctrl"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::CTRL, "Ctrl"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::BACKSLASH, "\\"},
    {Vhs::Token::ALT, "Alt"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::RIGHT_BRACKET, "]"},
    {Vhs::Token::SHIFT, "Shift"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::LEFT_BRACKET, "["},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, ".1"},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, "100"},
    {Vhs::Token::MILLISECONDS, "ms"},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::WAIT, "Wait"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "Screen"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::MINUTES, "m"},
    {Vhs::Token::REGEX, "foobar"},
    {Vhs::Token::WAIT, "Wait"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "Screen"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::MINUTES, "m"},
    {Vhs::Token::REGEX, "foo\\/bar"},
    {Vhs::Token::WAIT, "Wait"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "Screen"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::MINUTES, "m"},
    {Vhs::Token::REGEX, "foo\\\\"},
    {Vhs::Token::WAIT, "Wait"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "Screen"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::MINUTES, "m"},
    {Vhs::Token::REGEX, "foo\\\\\\/bar"},
  ]
end

private def tape_file_expectations
  [
    {Vhs::Token::COMMENT, " All Commands"},
    {Vhs::Token::COMMENT, " Output:"},
    {Vhs::Token::OUTPUT, "Output"},
    {Vhs::Token::STRING, "examples/fixtures/all.gif"},
    {Vhs::Token::OUTPUT, "Output"},
    {Vhs::Token::STRING, "examples/fixtures/all.mp4"},
    {Vhs::Token::OUTPUT, "Output"},
    {Vhs::Token::STRING, "examples/fixtures/all.webm"},
    {Vhs::Token::COMMENT, " Settings:"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::SHELL, "Shell"},
    {Vhs::Token::STRING, "fish"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::FONT_SIZE, "FontSize"},
    {Vhs::Token::NUMBER, "22"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::FONT_FAMILY, "FontFamily"},
    {Vhs::Token::STRING, "DejaVu Sans Mono"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::HEIGHT, "Height"},
    {Vhs::Token::NUMBER, "600"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::WIDTH, "Width"},
    {Vhs::Token::NUMBER, "1200"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::LETTER_SPACING, "LetterSpacing"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::LINE_HEIGHT, "LineHeight"},
    {Vhs::Token::NUMBER, "1.2"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::THEME, "Theme"},
    {Vhs::Token::JSON, "{ \"name\": \"Whimsy\", \"black\": \"#535178\", \"red\": \"#ef6487\", \"green\": \"#5eca89\", \"yellow\": \"#fdd877\", \"blue\": \"#65aef7\", \"purple\": \"#aa7ff0\", \"cyan\": \"#43c1be\", \"white\": \"#ffffff\", \"brightBlack\": \"#535178\", \"brightRed\": \"#ef6487\", \"brightGreen\": \"#5eca89\", \"brightYellow\": \"#fdd877\", \"brightBlue\": \"#65aef7\", \"brightPurple\": \"#aa7ff0\", \"brightCyan\": \"#43c1be\", \"brightWhite\": \"#ffffff\", \"background\": \"#29283b\", \"foreground\": \"#b3b0d6\", \"selectionBackground\": \"#3d3c58\", \"cursorColor\": \"#b3b0d6\" }"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::THEME, "Theme"},
    {Vhs::Token::STRING, "Catppuccin Mocha"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::PADDING, "Padding"},
    {Vhs::Token::NUMBER, "50"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::FRAMERATE, "Framerate"},
    {Vhs::Token::NUMBER, "60"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::PLAYBACK_SPEED, "PlaybackSpeed"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::TYPING_SPEED, "TypingSpeed"},
    {Vhs::Token::NUMBER, ".1"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::LOOP_OFFSET, "LoopOffset"},
    {Vhs::Token::NUMBER, "60.4"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::LOOP_OFFSET, "LoopOffset"},
    {Vhs::Token::NUMBER, "20.99"},
    {Vhs::Token::PERCENT, "%"},
    {Vhs::Token::SET, "Set"},
    {Vhs::Token::CURSOR_BLINK, "CursorBlink"},
    {Vhs::Token::BOOLEAN, "false"},
    {Vhs::Token::COMMENT, " Sleep:"},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, "500"},
    {Vhs::Token::MILLISECONDS, "ms"},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, ".5"},
    {Vhs::Token::SLEEP, "Sleep"},
    {Vhs::Token::NUMBER, "0.5"},
    {Vhs::Token::COMMENT, " Type:"},
    {Vhs::Token::TYPE, "Type"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, ".5"},
    {Vhs::Token::STRING, "All"},
    {Vhs::Token::TYPE, "Type"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "500"},
    {Vhs::Token::MILLISECONDS, "ms"},
    {Vhs::Token::STRING, "All"},
    {Vhs::Token::TYPE, "Type"},
    {Vhs::Token::STRING, "Double Quote"},
    {Vhs::Token::TYPE, "Type"},
    {Vhs::Token::STRING, "\"Single\" Quote"},
    {Vhs::Token::TYPE, "Type"},
    {Vhs::Token::STRING, "\"Backtick\" 'Quote'"},
    {Vhs::Token::COMMENT, " Keys:"},
    {Vhs::Token::BACKSPACE, "Backspace"},
    {Vhs::Token::BACKSPACE, "Backspace"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::BACKSPACE, "Backspace"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::DELETE, "Delete"},
    {Vhs::Token::DELETE, "Delete"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::DELETE, "Delete"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::INSERT, "Insert"},
    {Vhs::Token::INSERT, "Insert"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::INSERT, "Insert"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::DOWN, "Down"},
    {Vhs::Token::DOWN, "Down"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::DOWN, "Down"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::PAGE_DOWN, "PageDown"},
    {Vhs::Token::PAGE_DOWN, "PageDown"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::PAGE_DOWN, "PageDown"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::ENTER, "Enter"},
    {Vhs::Token::ENTER, "Enter"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::ENTER, "Enter"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::SPACE, "Space"},
    {Vhs::Token::SPACE, "Space"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::SPACE, "Space"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::TAB, "Tab"},
    {Vhs::Token::TAB, "Tab"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::TAB, "Tab"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::LEFT, "Left"},
    {Vhs::Token::LEFT, "Left"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::LEFT, "Left"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::RIGHT, "Right"},
    {Vhs::Token::RIGHT, "Right"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::RIGHT, "Right"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::UP, "Up"},
    {Vhs::Token::UP, "Up"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::UP, "Up"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::PAGE_UP, "PageUp"},
    {Vhs::Token::PAGE_UP, "PageUp"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::PAGE_UP, "PageUp"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::DOWN, "Down"},
    {Vhs::Token::DOWN, "Down"},
    {Vhs::Token::NUMBER, "2"},
    {Vhs::Token::DOWN, "Down"},
    {Vhs::Token::AT, "@"},
    {Vhs::Token::NUMBER, "1"},
    {Vhs::Token::NUMBER, "3"},
    {Vhs::Token::COMMENT, " Control:"},
    {Vhs::Token::CTRL, "Ctrl"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "C"},
    {Vhs::Token::CTRL, "Ctrl"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "L"},
    {Vhs::Token::CTRL, "Ctrl"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "R"},
    {Vhs::Token::COMMENT, " Alt:"},
    {Vhs::Token::ALT, "Alt"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "."},
    {Vhs::Token::ALT, "Alt"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "L"},
    {Vhs::Token::ALT, "Alt"},
    {Vhs::Token::PLUS, "+"},
    {Vhs::Token::STRING, "i"},
    {Vhs::Token::COMMENT, " Display:"},
    {Vhs::Token::HIDE, "Hide"},
    {Vhs::Token::SHOW, "Show"},
  ]
end

module Vhs
  describe Lexer do
    describe "#next_token" do
      it "tokenizes the upstream TestNextToken tape" do
        input = <<-'TAPE'
        Output examples/out.gif
        Set FontSize 42
        Set Padding 5
        Set CursorBlink false
        Type "echo 'Hello, world!'"
        Enter
        Type@.1 "echo 'Hello, world!'"
        Left 3
        Sleep 1
        Right@100ms 3
        Sleep 500ms
        Ctrl+C
        Enter
        Ctrl+@
        Ctrl+\
        Alt+]
        Shift+[
        Sleep .1
        Sleep 100ms
        Sleep 2
        Wait+Screen@1m /foobar/
        Wait+Screen@1m /foo\/bar/
        Wait+Screen@1m /foo\\/
        Wait+Screen@1m /foo\\\/bar/
        TAPE

        lexer = Lexer.new(input)
        next_token_expectations.each_with_index do |(expected_type, expected_literal), index|
          token = lexer.next_token
          unless token.type == expected_type && token.literal == expected_literal
            fail "tokens[#{index}]: expected #{expected_type}/#{expected_literal.inspect}, got #{token.type}/#{token.literal.inspect}"
          end
        end
      end

      it "tokenizes the upstream all.tape fixture" do
        lexer = Lexer.new(File.read(File.join(__DIR__, "..", "fixtures", "all.tape")))
        tape_file_expectations.each_with_index do |(expected_type, expected_literal), index|
          token = lexer.next_token
          unless token.type == expected_type && token.literal == expected_literal
            fail "tokens[#{index}]: expected #{expected_type}/#{expected_literal.inspect}, got #{token.type}/#{token.literal.inspect}"
          end
        end
      end

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
