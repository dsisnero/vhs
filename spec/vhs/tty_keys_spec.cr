require "../spec_helper"

module Vhs
  # Characterization specs for the tty.go port and the keys.go key map.
  describe Tty do
    describe ".build_tty_args" do
      it "matches upstream's ttyd arguments" do
        args = Tty.build_tty_args(4321, SHELLS["bash"])

        args.should eq([
          "--port=4321",
          "--interface", "127.0.0.1",
          "-t", "rendererType=canvas",
          "-t", "disableResizeOverlay=true",
          "-t", "enableSixel=true",
          "-t", "customGlyphs=true",
          "--once",
          "--writable",
          "bash", "--noprofile", "--norc", "--login", "+o", "history",
        ])
      end

      it "appends the shell's own command after the terminal flags" do
        shell = Shell.new(command: ["fish", "--login"], env: ["A=1"])
        args = Tty.build_tty_args(1, shell)

        args.last(2).should eq(["fish", "--login"])
        args.first.should eq("--port=1")
      end
    end

    describe ".random_port" do
      it "returns a usable TCP port" do
        port = Tty.random_port
        port.should be > 0
        port.should be <= 65_535
      end
    end
  end

  describe Keys do
    it "maps every rune upstream maps" do
      # upstream keys.go has 104 entries.
      Keys.keymap.size.should eq(104)
    end

    it "maps letters and shifted letters" do
      lowercase = Keys.key_for('a').as(Int32)
      uppercase = Keys.key_for('A').as(Int32)

      Rod::Input.key_info(lowercase).key.should eq("a")
      Rod::Input.key_info(uppercase).key.should eq("A")
      Rod::Input.key_info(lowercase).code.should eq("KeyA")
      Rod::Input.key_info(uppercase).code.should eq("KeyA")
    end

    it "maps shifted punctuation through the shift helper" do
      {"!" => "!", "|" => "|", "~" => "~", "{" => "{", ":" => ":"}.each do |char, expected|
        info = Rod::Input.key_info(Keys.key_for(char[0]).as(Int32))
        info.key.should eq(expected)
      end
    end

    it "maps digits and control runes" do
      Rod::Input.key_info(Keys.key_for('5').as(Int32)).key.should eq("5")
      Keys.key_for('\n').should eq(Rod::Input::ENTER)
      Keys.key_for('\r').should eq(Rod::Input::ENTER)
      Keys.key_for('\t').should eq(Rod::Input::TAB)
      Keys.key_for('\b').should eq(Rod::Input::BACKSPACE)
      Keys.key_for('\e').should eq(Rod::Input::ESCAPE)
    end

    it "maps arrow runes" do
      Keys.key_for('←').should eq(Rod::Input::ARROW_LEFT)
      Keys.key_for('↑').should eq(Rod::Input::ARROW_UP)
      Keys.key_for('→').should eq(Rod::Input::ARROW_RIGHT)
      Keys.key_for('↓').should eq(Rod::Input::ARROW_DOWN)
    end

    it "returns nil for runes upstream does not map" do
      Keys.key_for('日').should be_nil
    end
  end
end
