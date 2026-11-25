require "../spec_helper"
require "file_utils"

module Vhs
  # Characterization specs for upstream testing.go's Buffer, CurrentLine, and
  # SaveOutput. These drive a real xterm.js session, so they only run with
  # VHS_SPEC_BROWSER=1.
  describe "testing helpers" do
    it "returns the terminal buffer rows trimmed at the end" do
      next unless browser_specs?

      vhs = browser_vhs
      begin
        vhs.page.as(Rod::Page).eval("() => term.write('hello')")
        sleep 0.3.seconds

        lines = vhs.buffer
        lines.size.should eq(10)
        lines.join("\n").should contain("hello")
      ensure
        vhs.stop
      end
    end

    it "returns the line the cursor is on" do
      next unless browser_specs?

      vhs = browser_vhs
      begin
        vhs.page.as(Rod::Page).eval("() => term.write('first-line')")
        sleep 0.3.seconds
        vhs.current_line.should contain("first-line")

        vhs.page.as(Rod::Page).eval("() => term.write('\\r\\nsecond-line')")
        sleep 0.3.seconds
        vhs.current_line.should contain("second-line")
      ensure
        vhs.stop
      end
    end

    it "writes the buffer and an 80-column separator to the test output" do
      next unless browser_specs?

      Dir.mkdir_p("./temp")
      output = "./temp/testing-helpers/session.test"
      FileUtils.rm_rf("./temp/testing-helpers")

      vhs = browser_vhs
      begin
        vhs.options.test.output = output
        vhs.page.as(Rod::Page).eval("() => term.write('captured')")
        sleep 0.3.seconds

        vhs.save_output.should be_nil
        File.exists?(output).should be_true
        File.read(output).should contain("captured")
        File.read(output).should contain(SEPARATOR)
      ensure
        vhs.stop
        FileUtils.rm_rf("./temp/testing-helpers")
      end
    end

    it "appends on later calls instead of rewriting the file" do
      next unless browser_specs?

      Dir.mkdir_p("./temp")
      output = "./temp/testing-helpers/session.test"
      FileUtils.rm_rf("./temp/testing-helpers")

      vhs = browser_vhs
      begin
        vhs.options.test.output = output

        vhs.save_output.should be_nil
        vhs.save_output.should be_nil

        # Two buffers plus two separators.
        File.read(output).scan(SEPARATOR).size.should eq(2)
      ensure
        vhs.stop
        FileUtils.rm_rf("./temp/testing-helpers")
      end
    end

    it "does nothing when no test output is configured" do
      vhs = VHS.new
      vhs.options.test.output = ""
      vhs.save_output.should be_nil
    end
  end
end
