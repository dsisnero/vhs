require "../spec_helper"

# Tables and classifications mirrored from vendor/vhs/token/token.go
# (v0.10.0+19). Keeping them in the spec is what lets the ledger call the token
# constants `ported`.
private def token_constants
  [
    {"@", Vhs::Token::AT},
    {"=", Vhs::Token::EQUAL},
    {"+", Vhs::Token::PLUS},
    {"%", Vhs::Token::PERCENT},
    {"/", Vhs::Token::SLASH},
    {"\\", Vhs::Token::BACKSLASH},
    {".", Vhs::Token::DOT},
    {"-", Vhs::Token::DASH},
    {"-", Vhs::Token::MINUS},
    {"]", Vhs::Token::RIGHT_BRACKET},
    {"[", Vhs::Token::LEFT_BRACKET},
    {"^", Vhs::Token::CARET},
    {"EM", Vhs::Token::EM},
    {"MILLISECONDS", Vhs::Token::MILLISECONDS},
    {"MINUTES", Vhs::Token::MINUTES},
    {"PX", Vhs::Token::PX},
    {"SECONDS", Vhs::Token::SECONDS},
    {"EOF", Vhs::Token::EOF},
    {"ILLEGAL", Vhs::Token::ILLEGAL},
    {"ALT", Vhs::Token::ALT},
    {"BACKSPACE", Vhs::Token::BACKSPACE},
    {"CTRL", Vhs::Token::CTRL},
    {"DELETE", Vhs::Token::DELETE},
    {"END", Vhs::Token::END},
    {"ENTER", Vhs::Token::ENTER},
    {"ESCAPE", Vhs::Token::ESCAPE},
    {"HOME", Vhs::Token::HOME},
    {"INSERT", Vhs::Token::INSERT},
    {"PAGE_DOWN", Vhs::Token::PAGE_DOWN},
    {"PAGE_UP", Vhs::Token::PAGE_UP},
    {"SLEEP", Vhs::Token::SLEEP},
    {"SPACE", Vhs::Token::SPACE},
    {"TAB", Vhs::Token::TAB},
    {"SHIFT", Vhs::Token::SHIFT},
    {"COMMENT", Vhs::Token::COMMENT},
    {"NUMBER", Vhs::Token::NUMBER},
    {"STRING", Vhs::Token::STRING},
    {"JSON", Vhs::Token::JSON},
    {"REGEX", Vhs::Token::REGEX},
    {"BOOLEAN", Vhs::Token::BOOLEAN},
    {"DOWN", Vhs::Token::DOWN},
    {"LEFT", Vhs::Token::LEFT},
    {"RIGHT", Vhs::Token::RIGHT},
    {"UP", Vhs::Token::UP},
    {"HIDE", Vhs::Token::HIDE},
    {"OUTPUT", Vhs::Token::OUTPUT},
    {"REQUIRE", Vhs::Token::REQUIRE},
    {"SET", Vhs::Token::SET},
    {"SHOW", Vhs::Token::SHOW},
    {"SOURCE", Vhs::Token::SOURCE},
    {"TYPE", Vhs::Token::TYPE},
    {"SCREENSHOT", Vhs::Token::SCREENSHOT},
    {"COPY", Vhs::Token::COPY},
    {"PASTE", Vhs::Token::PASTE},
    {"SHELL", Vhs::Token::SHELL},
    {"ENV", Vhs::Token::ENV},
    {"FONT_FAMILY", Vhs::Token::FONT_FAMILY},
    {"FONT_SIZE", Vhs::Token::FONT_SIZE},
    {"FRAMERATE", Vhs::Token::FRAMERATE},
    {"PLAYBACK_SPEED", Vhs::Token::PLAYBACK_SPEED},
    {"HEIGHT", Vhs::Token::HEIGHT},
    {"WIDTH", Vhs::Token::WIDTH},
    {"LETTER_SPACING", Vhs::Token::LETTER_SPACING},
    {"LINE_HEIGHT", Vhs::Token::LINE_HEIGHT},
    {"TYPING_SPEED", Vhs::Token::TYPING_SPEED},
    {"PADDING", Vhs::Token::PADDING},
    {"THEME", Vhs::Token::THEME},
    {"LOOP_OFFSET", Vhs::Token::LOOP_OFFSET},
    {"MARGIN_FILL", Vhs::Token::MARGIN_FILL},
    {"MARGIN", Vhs::Token::MARGIN},
    {"WINDOW_BAR", Vhs::Token::WINDOW_BAR},
    {"WINDOW_BAR_SIZE", Vhs::Token::WINDOW_BAR_SIZE},
    {"CORNER_RADIUS", Vhs::Token::BORDER_RADIUS},
    {"WAIT", Vhs::Token::WAIT},
    {"WAIT_TIMEOUT", Vhs::Token::WAIT_TIMEOUT},
    {"WAIT_PATTERN", Vhs::Token::WAIT_PATTERN},
    {"CURSOR_BLINK", Vhs::Token::CURSOR_BLINK},
  ]
end

private def upstream_keywords
  [
    {"em", Vhs::Token::EM},
    {"px", Vhs::Token::PX},
    {"ms", Vhs::Token::MILLISECONDS},
    {"s", Vhs::Token::SECONDS},
    {"m", Vhs::Token::MINUTES},
    {"Set", Vhs::Token::SET},
    {"Sleep", Vhs::Token::SLEEP},
    {"Type", Vhs::Token::TYPE},
    {"Enter", Vhs::Token::ENTER},
    {"Space", Vhs::Token::SPACE},
    {"Backspace", Vhs::Token::BACKSPACE},
    {"Delete", Vhs::Token::DELETE},
    {"Insert", Vhs::Token::INSERT},
    {"Ctrl", Vhs::Token::CTRL},
    {"Alt", Vhs::Token::ALT},
    {"Shift", Vhs::Token::SHIFT},
    {"Down", Vhs::Token::DOWN},
    {"Left", Vhs::Token::LEFT},
    {"Right", Vhs::Token::RIGHT},
    {"Up", Vhs::Token::UP},
    {"PageUp", Vhs::Token::PAGE_UP},
    {"PageDown", Vhs::Token::PAGE_DOWN},
    {"Tab", Vhs::Token::TAB},
    {"Escape", Vhs::Token::ESCAPE},
    {"End", Vhs::Token::END},
    {"Hide", Vhs::Token::HIDE},
    {"Require", Vhs::Token::REQUIRE},
    {"Show", Vhs::Token::SHOW},
    {"Output", Vhs::Token::OUTPUT},
    {"Shell", Vhs::Token::SHELL},
    {"FontFamily", Vhs::Token::FONT_FAMILY},
    {"MarginFill", Vhs::Token::MARGIN_FILL},
    {"Margin", Vhs::Token::MARGIN},
    {"WindowBar", Vhs::Token::WINDOW_BAR},
    {"WindowBarSize", Vhs::Token::WINDOW_BAR_SIZE},
    {"BorderRadius", Vhs::Token::BORDER_RADIUS},
    {"FontSize", Vhs::Token::FONT_SIZE},
    {"Framerate", Vhs::Token::FRAMERATE},
    {"Height", Vhs::Token::HEIGHT},
    {"LetterSpacing", Vhs::Token::LETTER_SPACING},
    {"LineHeight", Vhs::Token::LINE_HEIGHT},
    {"PlaybackSpeed", Vhs::Token::PLAYBACK_SPEED},
    {"TypingSpeed", Vhs::Token::TYPING_SPEED},
    {"Padding", Vhs::Token::PADDING},
    {"Theme", Vhs::Token::THEME},
    {"Width", Vhs::Token::WIDTH},
    {"LoopOffset", Vhs::Token::LOOP_OFFSET},
    {"WaitTimeout", Vhs::Token::WAIT_TIMEOUT},
    {"WaitPattern", Vhs::Token::WAIT_PATTERN},
    {"Wait", Vhs::Token::WAIT},
    {"Source", Vhs::Token::SOURCE},
    {"CursorBlink", Vhs::Token::CURSOR_BLINK},
    {"true", Vhs::Token::BOOLEAN},
    {"false", Vhs::Token::BOOLEAN},
    {"Screenshot", Vhs::Token::SCREENSHOT},
    {"Copy", Vhs::Token::COPY},
    {"Paste", Vhs::Token::PASTE},
    {"Env", Vhs::Token::ENV},
  ]
end

module Vhs
  describe Token do
    it "matches upstream token constant values" do
      token_constants.size.should eq(77)
      token_constants.each do |(value, token)|
        token.to_s.should eq(value)
      end
    end

    it "matches upstream's keyword table" do
      Token::KEYWORDS.size.should eq(upstream_keywords.size)
      upstream_keywords.each do |(key, token)|
        Token.lookup_identifier(key).should eq(token)
      end
    end

    it "does not treat Home as a keyword" do
      # Upstream defines a HOME token (used by record.go) but never maps the
      # bare word to it, so `Home` stays a STRING identifier.
      Token.lookup_identifier("Home").should eq(Token::STRING)
    end

    describe ".setting?" do
      it "matches upstream IsSetting" do
        settings = token_constants.map(&.last).select { |token| Token.setting?(token) }
        settings.map(&.to_s).sort!.should eq(%w[
          CORNER_RADIUS CURSOR_BLINK FONT_FAMILY FONT_SIZE FRAMERATE HEIGHT
          LETTER_SPACING LINE_HEIGHT LOOP_OFFSET MARGIN MARGIN_FILL PADDING
          PLAYBACK_SPEED SHELL THEME TYPING_SPEED WAIT_PATTERN WAIT_TIMEOUT
          WIDTH WINDOW_BAR WINDOW_BAR_SIZE
        ])
      end

      it "returns false for non-setting tokens" do
        Token.setting?(Token::AT).should be_false
        Token.setting?(Token::EOF).should be_false
        Token.setting?(Token::TYPE).should be_false
      end
    end

    describe ".command?" do
      it "matches upstream IsCommand" do
        commands = token_constants.map(&.last).select { |token| Token.command?(token) }
        commands.map(&.to_s).sort!.should eq(%w[
          BACKSPACE COPY CTRL DELETE DOWN END ENTER ESCAPE HOME INSERT LEFT
          PAGE_DOWN PAGE_UP PASTE RIGHT SCREENSHOT SLEEP SOURCE TAB TYPE UP
          WAIT
        ])
      end

      it "returns false for non-command tokens" do
        Token.command?(Token::AT).should be_false
        Token.command?(Token::EOF).should be_false
        Token.command?(Token::FONT_SIZE).should be_false
      end
    end

    describe ".modifier?" do
      it "matches upstream IsModifier" do
        modifiers = token_constants.map(&.last).select { |token| Token.modifier?(token) }
        modifiers.map(&.to_s).sort!.should eq(%w[ALT SHIFT])
      end

      it "returns false for non-modifier tokens" do
        Token.modifier?(Token::CTRL).should be_false
        Token.modifier?(Token::ENTER).should be_false
      end
    end

    describe ".to_camel" do
      it "converts token names like upstream TestToCamel" do
        Token.to_camel("SIMPLE").should eq("Simple")
        Token.to_camel("MULTIPLE_WORDS").should eq("MultipleWords")
      end

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
