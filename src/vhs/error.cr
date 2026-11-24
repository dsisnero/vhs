module Vhs
  # InvalidSyntaxError is returned when the parser encounters one or more errors.
  class InvalidSyntaxError < Exception
    getter errors : Array(Parser::ParserError)

    def initialize(@errors : Array(Parser::ParserError))
    end

    # Upstream: fmt.Sprintf("parser: %d error(s)", len(e.Errors))
    def message : String
      "parser: #{errors.size} error(s)"
    end
  end

  # ErrorColumnOffset is the number of columns that an error should be printed to
  # the left to account for the line number.
  ERROR_COLUMN_OFFSET = 5

  # Upstream renders error text through lipgloss styles: `ErrorStyle` is color
  # "1", `LineNumberStyle` is color "8". lipgloss negotiates a color profile with
  # the terminal at runtime, so the port emits the 16-color ANSI codes those
  # styles resolve to on a color terminal.
  ERROR_STYLE       = "\e[31m"
  LINE_NUMBER_STYLE = "\e[90m"
  STYLE_RESET       = "\e[0m"

  # Underline returns a string of ^ characters which helps underline the
  # problematic token in a parser error.
  def self.underline(n : Int32) : String
    "#{ERROR_STYLE}#{"^" * n}#{STYLE_RESET}"
  end

  # LineNumber returns a formatted version of the given line number.
  def self.line_number(line : Int32) : String
    "#{LINE_NUMBER_STYLE} #{sprintf("%2d", line)} │ #{STYLE_RESET}"
  end

  # print_error prints a parser error with the offending tape line, a line number
  # gutter, and a caret underline beneath the token.
  def self.print_error(io : IO, tape : String, err : Parser::ParserError) : Nil
    lines = tape.split('\n')
    line = err.token.line
    io << line_number(line)
    io.puts tape_line(lines, line)
    io << " " * (err.token.column + ERROR_COLUMN_OFFSET)
    # Upstream underlines len(Token.Literal) bytes, not characters.
    io.puts "#{underline(err.token.literal.bytesize)} #{err.message}"
    io.puts
  end

  # print_errors prints each error, expanding an InvalidSyntaxError into its
  # individual parser errors first.
  def self.print_errors(io : IO, tape : String, errs : Enumerable(Exception)) : Nil
    errs.each do |err|
      if err.is_a?(InvalidSyntaxError)
        err.errors.each { |parser_err| print_error(io, tape, parser_err) }
      end
      io.puts "#{ERROR_STYLE}#{err.message}#{STYLE_RESET}"
    end
  end

  # Upstream indexes the split tape line directly, which panics on an
  # out-of-range line; the port prints an empty line instead of raising.
  private def self.tape_line(lines : Array(String), line : Int32) : String
    index = line - 1
    return "" if index < 0

    lines[index]? || ""
  end
end
