require "./token"

module Vhs
  # Lexer provides a lexer for the VHS Tape language.
  class Lexer
    @ch : Char = '\0'
    @input : String
    @pos : Int32
    @next_pos : Int32
    @line : Int32
    @column : Int32

    # Creates a new lexer for tokenizing the input string.
    def initialize(input : String)
      @input = input
      @pos = 0
      @next_pos = 0
      @line = 1
      @column = 0
      read_char
    end

    # Returns the next token in the input.
    # ameba:disable Metrics/CyclomaticComplexity
    def next_token : Token::Token
      skip_whitespace

      line = @line
      column = @column

      case @ch
      when '\0'
        token = new_token(Token::EOF, @ch)
        read_char
        token
      when '@'
        token = new_token(Token::AT, @ch)
        read_char
        token
      when '='
        token = new_token(Token::EQUAL, @ch)
        read_char
        token
      when ']'
        token = new_token(Token::RIGHT_BRACKET, @ch)
        read_char
        token
      when '['
        token = new_token(Token::LEFT_BRACKET, @ch)
        read_char
        token
      when '-'
        token = new_token(Token::MINUS, @ch)
        read_char
        token
      when '%'
        token = new_token(Token::PERCENT, @ch)
        read_char
        token
      when '^'
        token = new_token(Token::CARET, @ch)
        read_char
        token
      when '\\'
        token = new_token(Token::BACKSLASH, @ch)
        read_char
        token
      when '#'
        type = Token::COMMENT
        literal = read_comment
        Token::Token.new(type, literal, line, column)
      when '+'
        token = new_token(Token::PLUS, @ch)
        read_char
        token
      when '{'
        type = Token::JSON
        literal = "{" + read_json + "}"
        read_char
        Token::Token.new(type, literal, line, column)
      when '`'
        type = Token::STRING
        literal = read_string('`')
        read_char
        Token::Token.new(type, literal, line, column)
      when '\''
        type = Token::STRING
        literal = read_string('\'')
        read_char
        Token::Token.new(type, literal, line, column)
      when '"'
        type = Token::STRING
        literal = read_string('"')
        read_char
        Token::Token.new(type, literal, line, column)
      when '/'
        type = Token::REGEX
        literal = read_regex('/')
        read_char
        Token::Token.new(type, literal, line, column)
      else
        if digit?(@ch) || (dot?(@ch) && digit?(peek_char))
          literal = read_number
          Token::Token.new(Token::NUMBER, literal, line, column)
        elsif letter?(@ch) || dot?(@ch)
          literal = read_identifier
          type = Token.lookup_identifier(literal)
          Token::Token.new(type, literal, line, column)
        else
          token = new_token(Token::ILLEGAL, @ch)
          read_char
          token
        end
      end
    end

    # Creates a new token with the given type and literal.
    private def new_token(token_type : Token::Type, ch : Char) : Token::Token
      literal = ch.to_s
      Token::Token.new(token_type, literal, @line, @column)
    end

    # Reads a comment.
    # // Foo => Token(Foo).
    private def read_comment : String
      pos = @pos + 1
      loop do
        read_char
        break if newline?(@ch) || @ch == '\0'
      end
      # The current character is a newline.
      # skip_whitespace() will handle this for us and increment the line counter.
      @input[pos...@pos]
    end

    # Reads a string from the input.
    # "Foo" => Token(Foo).
    private def read_string(end_char : Char) : String
      pos = @pos + 1
      loop do
        read_char
        break if @ch == end_char || @ch == '\0' || newline?(@ch)
      end
      @input[pos...@pos]
    end

    # Reads a regex pattern from the input, handling escaped delimiters.
    # It counts consecutive backslashes to determine if a delimiter is truly escaped.
    # Examples:
    #   /foo\/bar/ => Token(foo\/bar) - delimiter is escaped
    #   /foo\\/    => Token(foo\\)    - delimiter is NOT escaped (backslash is escaped)
    #   /foo\\\/bar/ => Token(foo\\\/bar) - delimiter is escaped
    private def read_regex(end_char : Char) : String
      pos = @pos + 1
      loop do
        read_char
        break if @ch == '\0' || newline?(@ch)

        if @ch == '\\'
          backslash_count = 0

          while @ch == '\\' && @pos < @input.size
            backslash_count += 1
            read_char
          end

          if @ch == end_char
            # Odd number of backslashes means the delimiter is escaped
            next if backslash_count.odd?
            # Even number of backslashes means the delimiter is NOT escaped
            # This is the end of the regex
            break
          end

          next
        end

        break if @ch == end_char
      end
      @input[pos...@pos]
    end

    # Reads a JSON object from the input.
    # {"foo": "bar"} => Token({"foo": "bar"}).
    private def read_json : String
      pos = @pos + 1
      loop do
        read_char
        break if @ch == '}' || @ch == '\0'
      end
      @input[pos...@pos]
    end

    # Reads a number from the input.
    # 123 => Token(123).
    private def read_number : String
      pos = @pos
      while digit?(@ch) || dot?(@ch)
        read_char
      end
      @input[pos...@pos]
    end

    # Reads an identifier from the input.
    # Foo => Token(Foo).
    private def read_identifier : String
      pos = @pos
      while letter?(@ch) || dot?(@ch) || dash?(@ch) || underscore?(@ch) || slash?(@ch) || percent?(@ch) || digit?(@ch)
        read_char
      end
      @input[pos...@pos]
    end

    # Skips whitespace characters.
    # If it encounters a newline, it increments the line counter to keep track
    # of the token's line number.
    private def skip_whitespace
      while whitespace?(@ch)
        # Note: we don't use newline? since we don't want to double count \r\n on
        # windows and increment the @line.
        if @ch == '\n'
          @line += 1
          @column = 0
        end
        read_char
      end
    end

    # Advances the lexer to the next character.
    private def read_char
      @column += 1
      @ch = peek_char
      @pos = @next_pos
      @next_pos += 1
    end

    # Returns the next character in the input without advancing the lexer.
    private def peek_char : Char
      return '\0' if @next_pos >= @input.size
      @input[@next_pos]
    end

    # Character classification helpers

    private def dot?(ch : Char) : Bool
      ch == '.'
    end

    private def dash?(ch : Char) : Bool
      ch == '-'
    end

    private def underscore?(ch : Char) : Bool
      ch == '_'
    end

    private def percent?(ch : Char) : Bool
      ch == '%'
    end

    private def slash?(ch : Char) : Bool
      ch == '/'
    end

    private def letter?(ch : Char) : Bool
      ('a' <= ch && ch <= 'z') || ('A' <= ch && ch <= 'Z')
    end

    private def digit?(ch : Char) : Bool
      '0' <= ch && ch <= '9'
    end

    private def whitespace?(ch : Char) : Bool
      ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
    end

    private def newline?(ch : Char) : Bool
      ch == '\n' || ch == '\r'
    end
  end
end
