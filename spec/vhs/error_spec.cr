require "../spec_helper"

private def strip_ansi(text : String) : String
  text.gsub(/\e\[[0-9;]*m/, "")
end

module Vhs
  # Characterization specs for the upstream error.go display helpers
  # (LineNumber, Underline, printError, printErrors). Upstream has no Go test
  # file for them, so the assertions pin the printed layout.
  describe "error" do
    describe "InvalidSyntaxError" do
      it "reports the number of parser errors" do
        errs = [
          Parser::ParserError.new(Token::Token.new(Token::ILLEGAL, "Bogus", 1, 1), "Invalid command: Bogus"),
          Parser::ParserError.new(Token::Token.new(Token::ILLEGAL, "Nope", 2, 1), "Invalid command: Nope"),
        ]
        error = InvalidSyntaxError.new(errs)
        error.errors.size.should eq(2)
        error.message.should eq("parser: 2 error(s)")
      end
    end

    describe "ERROR_COLUMN_OFFSET" do
      it "matches upstream" do
        ERROR_COLUMN_OFFSET.should eq(5)
      end
    end

    describe ".underline" do
      it "repeats a caret per character" do
        strip_ansi(Vhs.underline(4)).should eq("^^^^")
      end

      it "renders the caret run in the error style" do
        Vhs.underline(3).should eq(Vhs::Styles::ERROR_STYLE.render("^^^"))
      end

      it "is empty for zero length" do
        strip_ansi(Vhs.underline(0)).should eq("")
      end
    end

    describe ".line_number" do
      it "right-aligns the number in a gutter" do
        strip_ansi(Vhs.line_number(3)).should eq("  3 │ ")
        strip_ansi(Vhs.line_number(42)).should eq(" 42 │ ")
        strip_ansi(Vhs.line_number(123)).should eq(" 123 │ ")
      end

      it "renders the gutter in the line number style" do
        Vhs.line_number(7).should eq(Vhs::Styles::LINE_NUMBER_STYLE.render("  7 │ "))
      end
    end

    describe ".print_error" do
      it "prints the tape line, a caret underline, and the message" do
        tape = "Sleep 1s\nOutput\nType \"hi\"\n"
        err = Parser::ParserError.new(
          Token::Token.new(Token::OUTPUT, "Output", 2, 1),
          "expected a file name"
        )
        io = IO::Memory.new

        Vhs.print_error(io, tape, err)

        strip_ansi(io.to_s).should eq("  2 │ Output\n      ^^^^^^ expected a file name\n\n")
      end

      it "indents the caret line by the token column plus the gutter offset" do
        tape = "Sleep 1s\nSet FontSize 1.5\n"
        err = Parser::ParserError.new(
          Token::Token.new(Token::ILLEGAL, "1.5", 2, 14),
          "invalid font size"
        )
        io = IO::Memory.new

        Vhs.print_error(io, tape, err)
        lines = strip_ansi(io.to_s).lines

        lines[1].should eq("#{" " * (14 + ERROR_COLUMN_OFFSET)}^^^ invalid font size")
      end

      it "prints an empty tape line when the line number is out of range" do
        err = Parser::ParserError.new(Token::Token.new(Token::ILLEGAL, "x", 9, 1), "boom")
        io = IO::Memory.new

        Vhs.print_error(io, "Sleep 1s\n", err)

        strip_ansi(io.to_s).should eq("  9 │ \n      ^ boom\n\n")
      end
    end

    describe ".print_errors" do
      it "expands an InvalidSyntaxError into each parser error" do
        tape = "Sleep 1s\nBogus\nNope\n"
        error = InvalidSyntaxError.new([
          Parser::ParserError.new(Token::Token.new(Token::ILLEGAL, "Bogus", 2, 1), "Invalid command: Bogus"),
          Parser::ParserError.new(Token::Token.new(Token::ILLEGAL, "Nope", 3, 1), "Invalid command: Nope"),
        ])
        io = IO::Memory.new

        Vhs.print_errors(io, tape, [error] of Exception)

        strip_ansi(io.to_s).should eq(
          "  2 │ Bogus\n      ^^^^^ Invalid command: Bogus\n\n" \
          "  3 │ Nope\n      ^^^^ Invalid command: Nope\n\n" \
          "parser: 2 error(s)\n"
        )
      end

      it "prints a non-syntax error message in the error style" do
        io = IO::Memory.new

        Vhs.print_errors(io, "", [IO::Error.new("disk on fire")] of Exception)

        strip_ansi(io.to_s).should eq("disk on fire\n")
        io.to_s.should eq("#{Vhs::Styles::ERROR_STYLE.render("disk on fire")}\n")
      end

      it "prints parser output for a tape that fails to parse" do
        next unless browser_specs?

        tape = "Bogus 3\n"
        errors = evaluate_without_render(tape)
        errors.size.should eq(1)
        errors.first.should be_a(InvalidSyntaxError)

        io = IO::Memory.new
        Vhs.print_errors(io, tape, errors)
        printed = strip_ansi(io.to_s)

        printed.should contain("  1 │ Bogus 3")
        printed.should contain("^")
        printed.should contain("parser: 2 error(s)")
      end
    end
  end
end
