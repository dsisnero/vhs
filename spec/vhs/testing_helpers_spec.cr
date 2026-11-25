require "../spec_helper"
require "file_utils"

private def testing_quiet_vhs : Vhs::VHS
  options = Vhs.default_vhs_options
  # A silent shell keeps the emulator buffer under the spec's control.
  options.shell = Vhs::Shell.new(command: ["sleep", "30"])
  # Low framerate: these specs care about the emulator, not about rendering
  # dozens of PNG frames.
  options.video.framerate = 2
  vhs = Vhs::VHS.new
  vhs.options = options
  vhs.start
  vhs
end

module Vhs
  # Characterization specs for upstream testing.go's Buffer, CurrentLine, and
  # SaveOutput. The terminal is driven with a silent shell (`sleep`) so the
  # buffer contents are deterministic instead of depending on a login shell.
  describe "testing helpers" do
    it "returns the terminal buffer rows trimmed at the end" do
      vhs = testing_quiet_vhs
      terminal = vhs.terminal.as(Vhs::TerminalEmulator)
      terminal.buffer = [
        ['h', 'i', ' ', ' '],
        [' ', ' ', ' ', ' '],
      ]

      vhs.buffer.should eq(["hi", ""])
      vhs.stop
    end

    it "returns the line the cursor is on" do
      vhs = testing_quiet_vhs
      terminal = vhs.terminal.as(Vhs::TerminalEmulator)
      terminal.buffer = [
        ['f', 'i', 'r', 's', 't'],
        ['s', 'e', 'c', 'o', 'n', 'd'],
        ['t', 'h', 'i', 'r', 'd'],
      ]

      terminal.cursor_y = 1
      vhs.current_line.should eq("second")

      terminal.cursor_y = 2
      vhs.current_line.should eq("third")
      vhs.stop
    end

    it "writes the buffer and an 80-column separator to the test output" do
      Dir.mkdir_p("./temp")
      output = "./temp/testing-helpers/session.test"
      FileUtils.rm_rf("./temp/testing-helpers")

      vhs = testing_quiet_vhs
      vhs.options.test.output = output
      terminal = vhs.terminal.as(Vhs::TerminalEmulator)
      terminal.buffer = [
        ['o', 'n', 'e'],
        ['t', 'w', 'o'],
      ]

      vhs.save_output.should be_nil
      File.exists?(output).should be_true
      File.read(output).should eq("one\ntwo\n#{SEPARATOR}\n")
      vhs.stop
      FileUtils.rm_rf("./temp/testing-helpers")
    end

    it "appends on later calls instead of rewriting the file" do
      Dir.mkdir_p("./temp")
      output = "./temp/testing-helpers/session.test"
      FileUtils.rm_rf("./temp/testing-helpers")

      vhs = testing_quiet_vhs
      vhs.options.test.output = output
      terminal = vhs.terminal.as(Vhs::TerminalEmulator)
      terminal.buffer = [['o', 'n', 'e']]

      vhs.save_output.should be_nil
      vhs.save_output.should be_nil

      File.read(output).should eq("one\n#{SEPARATOR}\none\n#{SEPARATOR}\n")
      vhs.stop
      FileUtils.rm_rf("./temp/testing-helpers")
    end

    it "does nothing when no test output is configured" do
      vhs = testing_quiet_vhs
      vhs.options.test.output = ""
      vhs.save_output.should be_nil
      vhs.stop
    end
  end
end
