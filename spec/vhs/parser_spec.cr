require "../spec_helper"
require "file_utils"

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
          {type: Token::SET, options: "TypingSpeed", args: "100ms"},
          {type: Token::SET, options: "WaitTimeout", args: "1m"},
          {type: Token::SET, options: "WaitPattern", args: "foo"},
          {type: Token::TYPE, options: "", args: "echo 'Hello, World!'"},
          {type: Token::ENTER, options: "", args: "1"},
          {type: Token::BACKSPACE, options: "0.1s", args: "5"},
          {type: Token::BACKSPACE, options: ".1s", args: "5"},
          {type: Token::BACKSPACE, options: "1s", args: "5"},
          {type: Token::BACKSPACE, options: "100ms", args: "5"},
          {type: Token::DELETE, options: "", args: "2"},
          {type: Token::INSERT, options: "", args: "2"},
          {type: Token::RIGHT, options: "", args: "3"},
          {type: Token::LEFT, options: "", args: "3"},
          {type: Token::UP, options: "50ms", args: "1"},
          {type: Token::DOWN, options: "", args: "2"},
          {type: Token::CTRL, options: "", args: "C"},
          {type: Token::CTRL, options: "", args: "L"},
          {type: Token::ALT, options: "", args: "."},
          {type: Token::SLEEP, options: "", args: "100ms"},
          {type: Token::SLEEP, options: "", args: "3s"},
          {type: Token::WAIT, options: "", args: "Line"},
          {type: Token::WAIT, options: "", args: "Screen"},
          {type: Token::WAIT, options: "100ms", args: "Line foobar"},
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
      it "collects errors for invalid commands" do
        input = <<-TAPE
        Type Enter
        Type "echo 'Hello, World!'" Enter
        Foo
        Sleep Bar
        TAPE

        expected_errors = [
          " 1:6  │ Type expects string",
          " 3:1  │ Invalid command: Foo",
          " 4:1  │ Expected time after Sleep",
          " 4:7  │ Invalid command: Bar",
        ]

        lexer = Lexer.new(input)
        parser = Parser.new(lexer)
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
      it "parses the all.tape fixture" do
        input = File.read("spec/fixtures/all.tape")
        lexer = Lexer.new(input)
        parser = Parser.new(lexer)
        commands = parser.parse

        # Basic sanity check - should parse without errors
        parser.errors.size.should eq(0)
        commands.size.should be > 0

        # Check first few commands match expected types
        commands[0].type.should eq(Token::OUTPUT)
        commands[0].options.should eq(".gif")
        commands[0].args.should eq("examples/fixtures/all.gif")

        commands[1].type.should eq(Token::OUTPUT)
        commands[1].options.should eq(".mp4")
        commands[1].args.should eq("examples/fixtures/all.mp4")

        commands[2].type.should eq(Token::OUTPUT)
        commands[2].options.should eq(".webm")
        commands[2].args.should eq("examples/fixtures/all.webm")

        # Check SET commands are present
        set_commands = commands.select { |cmd| cmd.type == Token::SET }
        set_commands.size.should be > 10

        # Check for specific SET commands
        shell_cmd = set_commands.find { |cmd| cmd.options == "Shell" }
        shell_cmd.should_not be_nil
        shell_cmd = shell_cmd.as(Vhs::Parser::Command)
        shell_cmd.args.should eq("fish")
      end
    end
  end
end
