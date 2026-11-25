require "../spec_helper"
require "file_utils"

private def behavior_vhs : Vhs::VHS
  options = Vhs.default_vhs_options
  # A silent shell keeps the terminal free of prompt output.
  options.shell = Vhs::Shell.new(command: ["sleep", "30"])
  options.style.width = 640
  options.style.height = 320
  options.style.padding = 20
  options.style.background_color = Vhs::BACKGROUND
  options.video.framerate = 2
  vhs = Vhs::VHS.new
  vhs.options = options
  vhs.start.should be_nil
  vhs.setup.should be_nil
  vhs.begin_recording
  vhs
end

private def behavior_command(type : Vhs::Token::Type, options : String = "", args : String = "") : Vhs::Parser::Command
  Vhs::Parser::Command.new(type, options, args)
end

module Vhs
  # Characterization specs for the command behaviors that upstream asserts
  # through the browser: the port writes to the terminal instead, so these pin
  # the observable effects.
  describe "command behavior" do
    describe "Execute" do
      it "wraps command failures with upstream's prefix" do
        next unless browser_specs?
        vhs = behavior_vhs
        error = Vhs.execute(behavior_command(Token::SET, "FontSize", "nope"), vhs)

        error.to_s.should contain("failed to execute command:")
        error.to_s.should contain("invalid font size")
        vhs.stop
      end

      it "falls back to a temporary file when the output directory cannot be created" do
        next unless browser_specs?
        vhs = behavior_vhs
        # Upstream writes to a temp file instead of failing when mkdir fails.
        vhs.options.test.output = "/dev/null/nope/session.test"

        Vhs.execute(behavior_command(Token::SLEEP, "", "1ms"), vhs).should be_nil
        vhs.stop
      end

      it "reports a missing command function" do
        next unless browser_specs?
        vhs = behavior_vhs
        Vhs.execute(behavior_command(Token::BOOLEAN, "", "true"), vhs)
          .to_s.should contain("no command function")
        vhs.stop
      end
    end

    describe "ExecuteOutput" do
      it "routes every extension to the matching output" do
        next unless browser_specs?
        tape = <<-TAPE
        Output demo.gif
        Output demo.mp4
        Output demo.webm
        Output frames/
        Output temp/command-behavior/session.test
        Sleep 0.1s
        TAPE

        seen = nil
        inspect_outputs = ->(v : VHS) do
          options = v.options
          seen = {
            options.video.output.gif,
            options.video.output.mp4,
            options.video.output.webm,
            options.video.output.frames,
            options.test.output,
          }
          options.video.output = VideoOutputs.new
          options.test.output = ""
          nil
        end

        Vhs.evaluate(tape, IO::Memory.new, inspect_outputs, drop_outputs_option).should be_empty
        seen.should eq({"demo.gif", "demo.mp4", "demo.webm", "frames/", "temp/command-behavior/session.test"})
      end
    end

    describe "ExecuteCopy and ExecutePaste" do
      it "stores the arguments in the clipboard and leaves Paste a no-op when empty" do
        next unless browser_specs?
        vhs = behavior_vhs
        Vhs.clipboard = ""

        Vhs.execute(behavior_command(Token::PASTE), vhs).should be_nil
        Vhs.execute(behavior_command(Token::COPY, "", "hello"), vhs).should be_nil
        Vhs.clipboard.should eq("hello")

        Vhs.execute(behavior_command(Token::PASTE), vhs).should be_nil
        vhs.stop
        Vhs.clipboard = ""
      end
    end

    describe "ExecuteHide and ExecuteShow" do
      it "toggles the recording flag" do
        next unless browser_specs?
        vhs = behavior_vhs

        Vhs.execute(behavior_command(Token::HIDE), vhs).should be_nil
        vhs.recording?.should be_false

        Vhs.execute(behavior_command(Token::SHOW), vhs).should be_nil
        vhs.recording?.should be_true
        vhs.stop
      end
    end

    describe "ExecuteSleep" do
      it "sleeps for the parsed duration" do
        next unless browser_specs?
        vhs = behavior_vhs
        started = Time.instant

        Vhs.execute(behavior_command(Token::SLEEP, "", "60ms"), vhs).should be_nil

        (Time.instant - started).should be >= 55.milliseconds
        vhs.stop
      end
    end

    describe "ExecuteWait" do
      it "gives up after the command's timeout" do
        next unless browser_specs?
        vhs = behavior_vhs
        started = Time.instant

        # Nothing matches, so the wait runs out its 50ms budget and errors with
        # upstream's timeout message.
        command = behavior_command(Token::WAIT, "50ms", "Screen /never-matches/")
        error = Vhs.execute(command, vhs)

        error.to_s.should contain("timeout waiting for")
        (Time.instant - started).should be >= 45.milliseconds
        (Time.instant - started).should be < 5.seconds
        vhs.stop
      end

      it "rejects an unknown scope" do
        next unless browser_specs?
        vhs = behavior_vhs
        command = behavior_command(Token::WAIT, "20ms", "Window /x/")

        Vhs.execute(command, vhs).to_s.should contain("failed to execute command:")
        vhs.stop
      end
    end

    describe "WaitTick" do
      it "polls at upstream's interval" do
        WAIT_TICK.should eq(10.milliseconds)
      end
    end

    describe "FFmpegRenderer.render" do
      it "reports a missing ffmpeg instead of failing silently" do
        original_path = ENV["PATH"]?
        video = Vhs.default_video_options
        video.output = VideoOutputs.new(gif: "./temp/command-behavior/none.gif")

        begin
          ENV["PATH"] = "/nonexistent"
          error = FFmpegRenderer.render(video, ScreenshotOptions.new)
          error.to_s.should contain("ffmpeg is not installed")
        ensure
          ENV["PATH"] = original_path
        end
      end

      it "does nothing when no output is configured" do
        video = Vhs.default_video_options
        video.output = VideoOutputs.new
        FFmpegRenderer.render(video, ScreenshotOptions.new).should be_nil
      end
    end

    describe "ExecuteScreenshot" do
      it "arms the next frame and records it in the screenshots map" do
        next unless browser_specs?
        vhs = behavior_vhs
        path = "./temp/command-behavior/shot.png"
        FileUtils.rm_rf("./temp/command-behavior")

        Vhs.execute(behavior_command(Token::SCREENSHOT, "", path), vhs).should be_nil
        vhs.options.screenshot.frame_capture?.should be_true
        vhs.options.screenshot.next_screenshot_path.should eq(path)

        # The capture loop consumes the armed path and clears it again.
        deadline = Time.instant + 2.seconds
        until vhs.options.screenshot.screenshots.has_key?(path)
          break if Time.instant > deadline
          sleep 10.milliseconds
        end

        vhs.options.screenshot.screenshots[path]?.should_not be_nil
        vhs.options.screenshot.frame_capture?.should be_false
        vhs.options.screenshot.next_screenshot_path.should eq("")
        vhs.stop
        FileUtils.rm_rf("./temp/command-behavior")
      end

      it "rejects a missing path" do
        next unless browser_specs?
        vhs = behavior_vhs
        Vhs.execute(behavior_command(Token::SCREENSHOT), vhs)
          .to_s.should contain("Screenshot path is required")
        vhs.stop
      end
    end
  end
end
