require "../spec_helper"
require "file_utils"

# Commands expected from spec/fixtures/all.tape, transcribed from upstream
# parser_test.go::TestParseTapeFile (v0.10.0+19).
EXPECTED_TAPE_COMMANDS = [
  {type: Vhs::Token::OUTPUT, options: ".gif", args: "examples/fixtures/all.gif"},
  {type: Vhs::Token::OUTPUT, options: ".mp4", args: "examples/fixtures/all.mp4"},
  {type: Vhs::Token::OUTPUT, options: ".webm", args: "examples/fixtures/all.webm"},
  {type: Vhs::Token::SET, options: "Shell", args: "fish"},
  {type: Vhs::Token::SET, options: "FontSize", args: "22"},
  {type: Vhs::Token::SET, options: "FontFamily", args: "DejaVu Sans Mono"},
  {type: Vhs::Token::SET, options: "Height", args: "600"},
  {type: Vhs::Token::SET, options: "Width", args: "1200"},
  {type: Vhs::Token::SET, options: "LetterSpacing", args: "1"},
  {type: Vhs::Token::SET, options: "LineHeight", args: "1.2"},
  {type: Vhs::Token::SET, options: "Theme", args: "{ \"name\": \"Whimsy\", \"black\": \"#535178\", \"red\": \"#ef6487\", \"green\": \"#5eca89\", \"yellow\": \"#fdd877\", \"blue\": \"#65aef7\", \"purple\": \"#aa7ff0\", \"cyan\": \"#43c1be\", \"white\": \"#ffffff\", \"brightBlack\": \"#535178\", \"brightRed\": \"#ef6487\", \"brightGreen\": \"#5eca89\", \"brightYellow\": \"#fdd877\", \"brightBlue\": \"#65aef7\", \"brightPurple\": \"#aa7ff0\", \"brightCyan\": \"#43c1be\", \"brightWhite\": \"#ffffff\", \"background\": \"#29283b\", \"foreground\": \"#b3b0d6\", \"selectionBackground\": \"#3d3c58\", \"cursorColor\": \"#b3b0d6\" }"},
  {type: Vhs::Token::SET, options: "Theme", args: "Catppuccin Mocha"},
  {type: Vhs::Token::SET, options: "Padding", args: "50"},
  {type: Vhs::Token::SET, options: "Framerate", args: "60"},
  {type: Vhs::Token::SET, options: "PlaybackSpeed", args: "2"},
  {type: Vhs::Token::SET, options: "TypingSpeed", args: ".1s"},
  {type: Vhs::Token::SET, options: "LoopOffset", args: "60.4%"},
  {type: Vhs::Token::SET, options: "LoopOffset", args: "20.99%"},
  {type: Vhs::Token::SET, options: "CursorBlink", args: "false"},
  {type: Vhs::Token::SLEEP, options: "", args: "1s"},
  {type: Vhs::Token::SLEEP, options: "", args: "500ms"},
  {type: Vhs::Token::SLEEP, options: "", args: ".5s"},
  {type: Vhs::Token::SLEEP, options: "", args: "0.5s"},
  {type: Vhs::Token::TYPE, options: ".5s", args: "All"},
  {type: Vhs::Token::TYPE, options: "500ms", args: "All"},
  {type: Vhs::Token::TYPE, options: "", args: "Double Quote"},
  {type: Vhs::Token::TYPE, options: "", args: "\"Single\" Quote"},
  {type: Vhs::Token::TYPE, options: "", args: "\"Backtick\" 'Quote'"},
  {type: Vhs::Token::BACKSPACE, options: "", args: "1"},
  {type: Vhs::Token::BACKSPACE, options: "", args: "2"},
  {type: Vhs::Token::BACKSPACE, options: "1s", args: "3"},
  {type: Vhs::Token::DELETE, options: "", args: "1"},
  {type: Vhs::Token::DELETE, options: "", args: "2"},
  {type: Vhs::Token::DELETE, options: "1s", args: "3"},
  {type: Vhs::Token::INSERT, options: "", args: "1"},
  {type: Vhs::Token::INSERT, options: "", args: "2"},
  {type: Vhs::Token::INSERT, options: "1s", args: "3"},
  {type: Vhs::Token::DOWN, options: "", args: "1"},
  {type: Vhs::Token::DOWN, options: "", args: "2"},
  {type: Vhs::Token::DOWN, options: "1s", args: "3"},
  {type: Vhs::Token::PAGE_DOWN, options: "", args: "1"},
  {type: Vhs::Token::PAGE_DOWN, options: "", args: "2"},
  {type: Vhs::Token::PAGE_DOWN, options: "1s", args: "3"},
  {type: Vhs::Token::ENTER, options: "", args: "1"},
  {type: Vhs::Token::ENTER, options: "", args: "2"},
  {type: Vhs::Token::ENTER, options: "1s", args: "3"},
  {type: Vhs::Token::SPACE, options: "", args: "1"},
  {type: Vhs::Token::SPACE, options: "", args: "2"},
  {type: Vhs::Token::SPACE, options: "1s", args: "3"},
  {type: Vhs::Token::TAB, options: "", args: "1"},
  {type: Vhs::Token::TAB, options: "", args: "2"},
  {type: Vhs::Token::TAB, options: "1s", args: "3"},
  {type: Vhs::Token::LEFT, options: "", args: "1"},
  {type: Vhs::Token::LEFT, options: "", args: "2"},
  {type: Vhs::Token::LEFT, options: "1s", args: "3"},
  {type: Vhs::Token::RIGHT, options: "", args: "1"},
  {type: Vhs::Token::RIGHT, options: "", args: "2"},
  {type: Vhs::Token::RIGHT, options: "1s", args: "3"},
  {type: Vhs::Token::UP, options: "", args: "1"},
  {type: Vhs::Token::UP, options: "", args: "2"},
  {type: Vhs::Token::UP, options: "1s", args: "3"},
  {type: Vhs::Token::PAGE_UP, options: "", args: "1"},
  {type: Vhs::Token::PAGE_UP, options: "", args: "2"},
  {type: Vhs::Token::PAGE_UP, options: "1s", args: "3"},
  {type: Vhs::Token::DOWN, options: "", args: "1"},
  {type: Vhs::Token::DOWN, options: "", args: "2"},
  {type: Vhs::Token::DOWN, options: "1s", args: "3"},
  {type: Vhs::Token::CTRL, options: "", args: "C"},
  {type: Vhs::Token::CTRL, options: "", args: "L"},
  {type: Vhs::Token::CTRL, options: "", args: "R"},
  {type: Vhs::Token::ALT, options: "", args: "."},
  {type: Vhs::Token::ALT, options: "", args: "L"},
  {type: Vhs::Token::ALT, options: "", args: "i"},
  {type: Vhs::Token::HIDE, options: "", args: ""},
  {type: Vhs::Token::SHOW, options: "", args: ""},
]

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

      it "parses all commands" do
        input = <<-TAPE
        Set TypingSpeed 100ms
        Set WaitTimeout 1m
        Set WaitPattern /foo/
        Type "echo 'Hello, World!'"
        Enter
        Backspace@0.1 5
        Backspace@.1 5
        Backspace@1 5
        Backspace@100ms 5
        Delete 2
        Insert 2
        Right 3
        Left 3
        Up@50ms
        Down 2
        Ctrl+C
        Ctrl+L
        Alt+.
        Sleep 100ms
        Sleep 3
        Wait
        Wait+Screen
        Wait@100ms /foobar/
        TAPE

        expected = [
          {type: Vhs::Token::SET, options: "TypingSpeed", args: "100ms"},
          {type: Vhs::Token::SET, options: "WaitTimeout", args: "1m"},
          {type: Vhs::Token::SET, options: "WaitPattern", args: "foo"},
          {type: Vhs::Token::TYPE, options: "", args: "echo 'Hello, World!'"},
          {type: Vhs::Token::ENTER, options: "", args: "1"},
          {type: Vhs::Token::BACKSPACE, options: "0.1s", args: "5"},
          {type: Vhs::Token::BACKSPACE, options: ".1s", args: "5"},
          {type: Vhs::Token::BACKSPACE, options: "1s", args: "5"},
          {type: Vhs::Token::BACKSPACE, options: "100ms", args: "5"},
          {type: Vhs::Token::DELETE, options: "", args: "2"},
          {type: Vhs::Token::INSERT, options: "", args: "2"},
          {type: Vhs::Token::RIGHT, options: "", args: "3"},
          {type: Vhs::Token::LEFT, options: "", args: "3"},
          {type: Vhs::Token::UP, options: "50ms", args: "1"},
          {type: Vhs::Token::DOWN, options: "", args: "2"},
          {type: Vhs::Token::CTRL, options: "", args: "C"},
          {type: Vhs::Token::CTRL, options: "", args: "L"},
          {type: Vhs::Token::ALT, options: "", args: "."},
          {type: Vhs::Token::SLEEP, options: "", args: "100ms"},
          {type: Vhs::Token::SLEEP, options: "", args: "3s"},
          {type: Vhs::Token::WAIT, options: "", args: "Line"},
          {type: Vhs::Token::WAIT, options: "", args: "Screen"},
          {type: Vhs::Token::WAIT, options: "100ms", args: "Line foobar"},
        ]

        lexer = Lexer.new(input)
        parser = Parser.new(lexer)
        commands = parser.parse

        commands.size.should eq(expected.size)
        expected.each_with_index do |exp, i|
          cmd = commands[i]
          cmd.type.should eq(exp[:type])
          cmd.options.should eq(exp[:options])
          cmd.args.should eq(exp[:args])
        end
      end
    end

    describe "#parse errors" do
      it "collects upstream TestParserErrors in tape order" do
        # Raw heredoc with a leading blank line: upstream's input starts with a
        # newline, so its errors are reported on lines 2, 4, 5 and 5.
        input = <<-'TAPE'

        Type Enter
        Type "echo 'Hello, World!'" Enter
        Foo
        Sleep Bar
        TAPE

        expected_errors = [
          " 2:6  │ Type expects string",
          " 4:1  │ Invalid command: Foo",
          " 5:1  │ Expected time after Sleep",
          " 5:7  │ Invalid command: Bar",
        ]

        parser = Parser.new(Lexer.new(input))
        parser.parse

        parser.errors.size.should eq(expected_errors.size)
        expected_errors.each_with_index do |expected, i|
          parser.errors[i].to_s.should eq(expected)
        end
      end
    end

    describe "#parse Ctrl modifier" do
      tests = [
        {
          name:      "should parse with multiple modifiers",
          tape:      "Ctrl+Shift+Alt+C",
          want_args: ["Shift", "Alt", "C"],
          want_err:  false,
        },
        {
          name:      "should not parse with out of order modifiers",
          tape:      "Ctrl+Shift+C+Alt",
          want_args: [] of String,
          want_err:  true,
        },
        {
          name:      "should not parse with out of order modifiers",
          tape:      "Ctrl+Shift+C+Alt+C",
          want_args: [] of String,
          want_err:  true,
        },
        {
          tape:      "Ctrl+Alt+Right",
          want_args: [] of String,
          want_err:  true,
        },
        {
          name:      "Ctrl+Backspace",
          tape:      "Ctrl+Backspace",
          want_args: ["Backspace"],
          want_err:  false,
        },
        {
          name:      "Ctrl+Space",
          tape:      "Ctrl+Space",
          want_args: ["Space"],
          want_err:  false,
        },
      ]

      tests.each do |test_case|
        it (test_case[:name]? || test_case[:tape]) do
          lexer = Lexer.new(test_case[:tape])
          parser = Parser.new(lexer)
          cmd = parser.parse.first
          if test_case[:want_err]
            parser.errors.size.should be > 0
          else
            parser.errors.size.should eq(0)
            args = cmd.args.split(" ")
            args.size.should eq(test_case[:want_args].size)
            test_case[:want_args].each_with_index do |want, i|
              args[i].should eq(want)
            end
          end
        end
      end
    end

    describe "#parse Source command" do
      temp_dir = "./temp"
      FileUtils.mkdir_p(temp_dir)

      it "should not return errors when tape exist and is NOT empty" do
        src_path = File.join(temp_dir, "source.tape")
        File.write(src_path, "Type \"echo 'Welcome to VHS!'\"")
        lexer = Lexer.new("Source #{src_path}")
        parser = Parser.new(lexer)
        parser.parse
        parser.errors.size.should eq(0)
        File.delete(src_path)
      end

      it "should return errors when tape NOT found" do
        src_path = File.join(temp_dir, "source.tape")
        lexer = Lexer.new("Source #{src_path}")
        parser = Parser.new(lexer)
        parser.parse
        parser.errors.size.should eq(1)
        parser.errors[0].message.should eq("File #{src_path} not found")
      end

      it "should return error when tape extension is NOT (.tape)" do
        src_path = File.join(temp_dir, "source.vhs")
        File.write(src_path, "")
        lexer = Lexer.new("Source #{src_path}")
        parser = Parser.new(lexer)
        parser.parse
        parser.errors.size.should eq(1)
        parser.errors[0].message.should eq("Expected file with .tape extension")
        File.delete(src_path)
      end

      it "should return error when Source command does NOT have tape path" do
        lexer = Lexer.new("Source")
        parser = Parser.new(lexer)
        parser.parse
        parser.errors.size.should eq(1)
        parser.errors[0].message.should eq("Expected path after Source")
      end

      it "should return error when find nested Source commands" do
        src_path = File.join(temp_dir, "source.tape")
        File.write(src_path, "Type \"echo 'Welcome to VHS!'\"\nSource magic.tape\nType \"goodbye\"\n")
        lexer = Lexer.new("Source #{src_path}")
        parser = Parser.new(lexer)
        parser.parse
        parser.errors.size.should eq(1)
        parser.errors[0].message.should eq("Nested Source detected")
        File.delete(src_path)
      end
    end

    describe "#parse Screenshot command" do
      it "should return error when screenshot extension is NOT (.png)" do
        lexer = Lexer.new("Screenshot step_one_screenshot.jpg")
        parser = Parser.new(lexer)
        parser.parse
        parser.errors.size.should eq(1)
        parser.errors[0].message.should eq("Expected file with .png extension")
      end

      it "should return error when screenshot path is missing" do
        lexer = Lexer.new("Screenshot")
        parser = Parser.new(lexer)
        parser.parse
        parser.errors.size.should eq(1)
        parser.errors[0].message.should eq("Expected path after Screenshot")
      end
    end

    describe "#parse tape file" do
      it "parses the all.tape fixture exactly like upstream TestParseTapeFile" do
        input = File.read(File.join(__DIR__, "..", "fixtures", "all.tape"))
        parser = Parser.new(Lexer.new(input))
        commands = parser.parse

        parser.errors.size.should eq(0)
        commands.size.should eq(EXPECTED_TAPE_COMMANDS.size)
        EXPECTED_TAPE_COMMANDS.each_with_index do |expected, i|
          command = commands[i]
          unless command.type == expected[:type] && command.options == expected[:options] && command.args == expected[:args]
            fail "commands[#{i}]: expected #{expected[:type]}/#{expected[:options].inspect}/#{expected[:args].inspect}, got #{command.type}/#{command.options.inspect}/#{command.args.inspect}"
          end
        end
      end
    end

    describe "#to_s" do
      it "renders the command type through ToCamel like upstream CommandType.String" do
        command = Parser::Command.new(Token::SET, "FontSize", "16")
        command.to_s.should eq("Set FontSize 16")
      end

      it "renders commands without options" do
        command = Parser::Command.new(Token::TYPE, "", "echo 'hi'")
        command.to_s.should eq("Type echo 'hi'")
      end

      it "renders commands without args" do
        Parser::Command.new(Token::HIDE).to_s.should eq("Hide ")
      end
    end
  end
end
