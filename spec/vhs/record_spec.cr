require "../spec_helper"

module Vhs
  describe "input_to_tape" do
    describe "ctrl key combinations" do
      it "converts input to tape format" do
        input = <<-INPUT
echo "Hello,.
BACKSPACE
LEFT
LEFT
RIGHT
RIGHT
 world"
ENTER
ENTER
ENTER
ls
ENTER
ENTER
BACKSPACE
CTRL+C
CTRL+C
CTRL+C
CTRL+W
CTRL+A
CTRL+E
SLEEP
SLEEP
ALT+.
SLEEP
exit
INPUT

        want = <<-WANT + "\n"
Type 'echo "Hello,.'
Backspace
Left 2
Right 2
Type ' world"'
Enter 3
Type "ls"
Enter 2
Backspace
Ctrl+C
Ctrl+C
Ctrl+C
Ctrl+W
Ctrl+A
Ctrl+E
Sleep 1s
Alt+.
Sleep 500ms
WANT

        got = Vhs.input_to_tape(input)
        got.should eq(want)
      end
    end

    describe "PageUp, PageDown #559" do
      it "converts PageUp/PageDown input" do
        input = <<-INPUT
echo "Hello,.
PAGE_UP
PAGE_UP
PAGE_UP
PAGE_UP
PAGE_UP
PAGE_UP
PAGE_UP
PAGE_UP
PAGE_DOWN
PAGE_DOWN
PAGE_DOWN
PAGE_DOWN
exit
INPUT

        want = <<-WANT + "\n"
Type 'echo "Hello,.'
PageUp 8
PageDown 4
WANT

        got = Vhs.input_to_tape(input)
        got.should eq(want)
      end
    end
  end

  describe "input_to_tape long sleep" do
    it "handles long sleep sequences" do
      input = "SLEEP\n" * 121 + "exit"
      want = "Sleep 60.5s\n"

      got = Vhs.input_to_tape(input)
      got.should eq(want)
    end
  end

  describe "input_to_tape repeated sleep after exit" do
    it "handles sleep after exit" do
      input = "SLEEP\nexit\nSLEEP\nSLEEP"
      want = "Sleep 500ms\nType \"exit\"\nSleep 1s\n"

      got = Vhs.input_to_tape(input)
      got.should eq(want)
    end
  end
end
