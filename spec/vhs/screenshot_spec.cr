require "../spec_helper"

module Vhs
  describe ScreenshotOptions do
    describe "#make_screenshot" do
      it "adds screenshot to map and disables capture" do
        path = "sample.png"
        target_frame = 60
        opts = ScreenshotOptions.new
        opts.enable_frame_capture(path)

        opts.make_screenshot(target_frame)

        # Check screenshot added to map
        frame = opts.screenshots[path]?
        frame.should_not be_nil
        frame.should eq(target_frame)

        # Check frame capture disabled
        opts.frame_capture.should be_false
      end
    end

    describe "#enable_frame_capture" do
      it "enables frame capture and sets next screenshot path" do
        path = "sample.png"
        opts = ScreenshotOptions.new(frame_capture: false)

        opts.enable_frame_capture(path)

        opts.frame_capture.should be_true
        opts.next_screenshot_path.should eq(path)
      end
    end
  end
end
