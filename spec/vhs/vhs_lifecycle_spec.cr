require "../spec_helper"
require "file_utils"

private def lifecycle_prepare_frames(dir : String, count : Int32) : Nil
  FileUtils.rm_rf(dir)
  Dir.mkdir_p(dir)
  (1..count).each do |frame|
    File.write(File.join(dir, sprintf(Vhs::TEXT_FRAME_FORMAT, frame)), "")
    File.write(File.join(dir, sprintf(Vhs::CURSOR_FRAME_FORMAT, frame)), "")
  end
end

# This checkout is on an exFAT volume where AppleDouble `._*` sidecars appear and
# vanish asynchronously, so a directory removal can still list stale entries for
# a few milliseconds. Poll instead of asserting immediately.
private def lifecycle_eventually(timeout_ms : Int32 = 500, & : -> Bool) : Bool
  deadline = Time.instant + timeout_ms.milliseconds
  loop do
    return true if yield
    return false if Time.instant > deadline

    sleep 10.milliseconds
  end
end

private def wait_for_frames(vhs : Vhs::VHS, count : Int32, timeout_ms : Int32 = 5000) : Bool
  lifecycle_eventually(timeout_ms) { vhs.total_frames >= count }
end

module Vhs
  # Characterization specs for the upstream vhs.go lifecycle methods the port
  # implements directly: ApplyLoopOffset, Setup, Start/Record, and Cleanup.
  describe VHS do
    describe "#apply_loop_offset" do
      it "returns an error when no frames were recorded" do
        vhs = VHS.new
        vhs.total_frames = 0

        error = vhs.apply_loop_offset
        error.to_s.should contain("no frames")
      end

      it "does nothing when the offset rounds to zero" do
        input = "./temp/loop-offset-none"
        lifecycle_prepare_frames(input, 4)

        vhs = VHS.new
        vhs.options.video.input = input
        vhs.options.loop_offset = 0.0
        vhs.total_frames = 4

        vhs.apply_loop_offset.should be_nil
        Dir.glob(File.join(input, "*.png")).size.should eq(8)
        FileUtils.rm_rf(input)
      end

      it "moves the first frames to the end and advances the starting frame" do
        input = "./temp/loop-offset"
        lifecycle_prepare_frames(input, 4)

        vhs = VHS.new
        vhs.options.video.input = input
        vhs.options.video.starting_frame = 1
        # 50% of 4 frames => offset 2: frames 1-2 move to 5-6.
        vhs.options.loop_offset = 50.0
        vhs.total_frames = 4

        vhs.apply_loop_offset.should be_nil
        vhs.options.video.starting_frame.should eq(3)

        File.exists?(File.join(input, sprintf(TEXT_FRAME_FORMAT, 5))).should be_true
        File.exists?(File.join(input, sprintf(CURSOR_FRAME_FORMAT, 5))).should be_true
        File.exists?(File.join(input, sprintf(TEXT_FRAME_FORMAT, 6))).should be_true
        File.exists?(File.join(input, sprintf(CURSOR_FRAME_FORMAT, 6))).should be_true
        # Frame 1 no longer exists under its original name.
        File.exists?(File.join(input, sprintf(TEXT_FRAME_FORMAT, 1))).should be_false
        FileUtils.rm_rf(input)
      end

      it "wraps offsets larger than the frame count" do
        input = "./temp/loop-offset-wrap"
        lifecycle_prepare_frames(input, 3)

        vhs = VHS.new
        vhs.options.video.input = input
        vhs.options.loop_offset = 250.0
        vhs.total_frames = 3

        # 250% of 3 = 7.5 -> 8, modulo 3 => 2.
        vhs.apply_loop_offset.should be_nil
        vhs.options.video.starting_frame.should eq(3)
        FileUtils.rm_rf(input)
      end
    end

    describe "#start and frame recording" do
      it "starts ttyd and a browser, then records frames until stopped" do
        next unless browser_specs?

        vhs = browser_vhs
        begin
          vhs.started?.should be_true
          vhs.page.should_not be_nil
          vhs.text_canvas.should_not be_nil

          vhs.begin_recording
          wait_for_frames(vhs, 1).should be_true
          vhs.total_frames.should be > 0

          # Both layers are written for every captured frame.
          input = vhs.options.video.input
          Dir.glob(File.join(input, sprintf(TEXT_FRAME_FORMAT, 1))).size.should eq(1)
          Dir.glob(File.join(input, sprintf(CURSOR_FRAME_FORMAT, 1))).size.should eq(1)
        ensure
          vhs.stop
        end
        vhs.started?.should be_false
      end

      it "stops capturing while recording is paused and resumes after" do
        next unless browser_specs?

        vhs = browser_vhs
        begin
          vhs.begin_recording
          wait_for_frames(vhs, 1)

          vhs.recording = false
          paused_at = vhs.total_frames
          sleep 0.3.seconds
          vhs.total_frames.should eq(paused_at)

          vhs.recording = true
          wait_for_frames(vhs, paused_at + 1)
          vhs.total_frames.should be > paused_at
        ensure
          vhs.stop
        end
      end
    end

    describe "#setup" do
      it "errors when the instance is not started" do
        VHS.new.setup.to_s.should contain("not started")
      end

      it "re-creates an empty frame directory" do
        next unless browser_specs?

        input = "./temp/setup-frames"
        lifecycle_prepare_frames(input, 2)

        vhs = browser_vhs
        begin
          vhs.options.video.input = input
          vhs.setup.should be_nil
          Dir.exists?(input).should be_true
          lifecycle_eventually { Dir.glob(File.join(input, "frame-*.png")).empty? }.should be_true
        ensure
          vhs.stop
          FileUtils.rm_rf(input)
        end
      end
    end

    describe "#cleanup" do
      it "removes the frame and screenshot directories" do
        input = "./temp/cleanup-frames"
        shots = "./temp/cleanup-shots"
        lifecycle_prepare_frames(input, 1)
        FileUtils.mkdir_p(shots)

        vhs = VHS.new
        vhs.options.video.input = input
        vhs.options.screenshot.input = shots

        vhs.cleanup.should be_nil
        lifecycle_eventually { !Dir.exists?(input) }.should be_true
        lifecycle_eventually { !Dir.exists?(shots) }.should be_true
      end
    end
  end
end
