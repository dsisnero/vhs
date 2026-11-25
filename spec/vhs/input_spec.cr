require "../spec_helper"

module Vhs
  # Characterization specs for Input, the port's synthesis of key sequences.
  # Upstream drives the browser's input layer instead, so these pin the bytes the
  # headless terminal receives.
  describe Input do
    describe ".key_sequence" do
      it "maps the named keys" do
        Input.key_sequence("Enter").should eq("\n")
        Input.key_sequence("Backspace").should eq("\b")
        Input.key_sequence("Delete").should eq("\u007f")
        Input.key_sequence("Insert").should eq("\e[2~")
        Input.key_sequence("Tab").should eq("\t")
        Input.key_sequence("Escape").should eq("\e")
        Input.key_sequence("Space").should eq(" ")
      end

      it "maps the navigation and paging keys" do
        Input.key_sequence("ArrowUp").should eq("\e[A")
        Input.key_sequence("ArrowDown").should eq("\e[B")
        Input.key_sequence("ArrowRight").should eq("\e[C")
        Input.key_sequence("ArrowLeft").should eq("\e[D")
        Input.key_sequence("PageUp").should eq("\e[5~")
        Input.key_sequence("PageDown").should eq("\e[6~")
        Input.key_sequence("Home").should eq("\e[1~")
        Input.key_sequence("End").should eq("\e[4~")
      end

      it "lowercases anything else" do
        Input.key_sequence("A").should eq("a")
        Input.key_sequence("z").should eq("z")
      end
    end

    describe ".alt_sequence" do
      it "prefixes named keys with ESC" do
        Input.alt_sequence("enter").should eq("\x1b\r")
        Input.alt_sequence("tab").should eq("\x1b\t")
        Input.alt_sequence("space").should eq("\x1b ")
        Input.alt_sequence("backspace").should eq("\x1b\b")
      end

      it "prefixes single characters with ESC" do
        Input.alt_sequence("a").should eq("\x1ba")
        Input.alt_sequence(".").should eq("\x1b.")
      end

      it "sends one Alt per character for multi-character keys" do
        Input.alt_sequence("ab").should eq("\x1ba\x1bb")
      end
    end

    describe ".shift_sequence" do
      it "maps control keys" do
        Input.shift_sequence("enter").should eq("\r")
        Input.shift_sequence("tab").should eq("\x1b[Z")
        Input.shift_sequence("space").should eq(" ")
        Input.shift_sequence("backspace").should eq("\b")
      end

      it "maps printable keys to their shifted characters" do
        Input.shift_sequence("1").should eq("!")
        Input.shift_sequence("2").should eq("@")
        Input.shift_sequence("[").should eq("{")
        Input.shift_sequence("\\").should eq("|")
        Input.shift_sequence("`").should eq("~")
        Input.shift_sequence("a").should eq("A")
        Input.shift_sequence("Z").should eq("Z")
      end

      it "uppercases multi-character keys" do
        Input.shift_sequence("ab").should eq("AB")
      end
    end

    describe ".ctrl_sequence" do
      it "writes C0 control characters for letters" do
        Input.ctrl_sequence(["C"]).should eq("\x03")
        Input.ctrl_sequence(["L"]).should eq("\x0c")
        Input.ctrl_sequence(["a"]).should eq("\x01")
        Input.ctrl_sequence(["z"]).should eq("\x1a")
      end

      it "maps the punctuation keys" do
        Input.ctrl_sequence(["["]).should eq("\x1b")
        Input.ctrl_sequence(["\\"]).should eq("\x1c")
        Input.ctrl_sequence(["]"]).should eq("\x1d")
        Input.ctrl_sequence(["^"]).should eq("\x1e")
        Input.ctrl_sequence(["_"]).should eq("\x1f")
        Input.ctrl_sequence(["?"]).should eq("\x7f")
      end

      it "maps named keys and skips modifiers" do
        Input.ctrl_sequence(["Enter"]).should eq("\r")
        Input.ctrl_sequence(["Space"]).should eq("\x00")
        Input.ctrl_sequence(["Backspace"]).should eq("\u007f")
        # Modifier chain members are modifiers, not control characters.
        Input.ctrl_sequence(["Shift", "Alt", "C"]).should eq("\x03")
      end

      it "ignores unknown keys" do
        Input.ctrl_sequence(["Right"]).should eq("")
      end
    end
  end
end
