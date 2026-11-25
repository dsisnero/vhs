require "../spec_helper"

private def builder_video_options(gif : String = "", mp4 : String = "", webm : String = "") : Vhs::VideoOptions
  Vhs::VideoOptions.new(
    framerate: 50,
    playback_speed: 1.0,
    input: "./temp/frames",
    output: Vhs::VideoOutputs.new(gif: gif, mp4: mp4, webm: webm),
    starting_frame: 1,
    style: Vhs::StyleOptions.new(width: 1200, height: 600, padding: 60, background_color: "#171717")
  )
end

module Vhs
  # Characterization specs for the ffmpeg.go/video.go port. Upstream has no Go
  # tests for the builders, so the assertions pin the generated arguments.
  describe "ffmpeg builders" do
    describe ".calc_term_dimensions" do
      it "subtracts the margin and window bar from the frame size" do
        style = StyleOptions.new(width: 1200, height: 600)
        Vhs.calc_term_dimensions(style).should eq({1200, 600})

        style.margin_fill = "#000000"
        style.margin = 10
        style.window_bar = "Colorful"
        style.window_bar_size = 30
        Vhs.calc_term_dimensions(style).should eq({1180, 550})
      end
    end

    describe ".margin_fill_is_color?" do
      it "treats hex colors as colors" do
        Vhs.margin_fill_is_color?("#ff0000").should be_true
        Vhs.margin_fill_is_color?("/tmp/background.png").should be_false
      end
    end

    describe FilterComplexBuilder do
      it "builds the video preamble with scale, fps, pad, and fillborders" do
        style = StyleOptions.new(width: 1200, height: 600, padding: 60, background_color: "#171717")
        video = VideoOptions.new(framerate: 50, playback_speed: 2.0, style: style)

        builder = FilterComplexBuilder.new_video(video)
        builder.prev_stage_name.should eq("padded")
        builder.term_width.should eq(1200)
        builder.term_height.should eq(600)
        builder.build.should eq([
          "-filter_complex",
          "\n\t\t[0][1]overlay[merged];" \
          "\n\t\t[merged]scale=1080:480:force_original_aspect_ratio=1[scaled];" \
          "\n\t\t[scaled]fps=50,setpts=PTS/2.000000[speed];" \
          "\n\t\t[speed]pad=1200:600:(ow-iw)/2:(oh-ih)/2:#171717[padded];" \
          "\n\t\t[padded]fillborders=left=60:right=60:top=60:bottom=60:mode=fixed:color=#171717[padded]" \
          "\n\t\t",
          "-map",
          "[padded]",
        ])
      end

      it "builds the screenshot preamble without fps and setpts" do
        style = StyleOptions.new(width: 1200, height: 600, padding: 60, background_color: "#171717")

        builder = FilterComplexBuilder.new_screenshot(style)
        builder.build[1].should contain("[merged]scale=1080:480:force_original_aspect_ratio=1[scaled]")
        builder.build[1].should_not contain("fps=")
        builder.build[1].should_not contain("setpts=")
      end

      it "chains the window bar, border radius, margin fill, and GIF stages" do
        style = StyleOptions.new(
          width: 1200, height: 600, padding: 60, background_color: "#171717",
          window_bar: "Colorful", window_bar_size: 30,
          border_radius: 12, margin_fill: "#2b2b2b", margin: 10
        )
        video = VideoOptions.new(framerate: 50, playback_speed: 1.0, style: style)

        builder = FilterComplexBuilder.new_video(video)
          .with_window_bar(3)
          .with_border_radius(4)
          .with_margin_fill(2)
          .with_gif

        builder.prev_stage_name.should eq("palette")
        filter = builder.build[1]
        filter.should contain("\n\t\t\t[3]loop=-1[loopbar];")
        filter.should contain("[loopbar][padded]overlay=0:30[withbar]")
        filter.should contain("\n\t\t\t[4]loop=-1[loopmask];")
        filter.should contain("[withbar][loopmask]alphamerge[rounded]")
        filter.should contain("\n\t\t\t[2]scale=1200:600[bg];")
        filter.should contain("[bg][rounded]overlay=(W-w)/2:(H-h)/2:shortest=1[withbg]")
        filter.should contain("[withbg]split[plt_a][plt_b];")
        builder.build[3].should eq("[palette]")
      end

      it "leaves the stage name untouched when a stage does not apply" do
        style = StyleOptions.new
        builder = FilterComplexBuilder.new_screenshot(style)
          .with_window_bar(3)
          .with_border_radius(4)
          .with_margin_fill(2)

        builder.prev_stage_name.should eq("padded")
        builder.build[3].should eq("[padded]")
      end
    end

    describe StreamBuilder do
      it "adds a lavfi color stream for a color margin fill" do
        style = StyleOptions.new(width: 1200, height: 600, margin_fill: "#2b2b2b", margin: 10)
        builder = StreamBuilder.new(2, "./temp", style).with_margin

        builder.args.should eq(["-f", "lavfi", "-i", "color=#2b2b2b:s=1200x600"])
        builder.margin_stream.should eq(2)
        builder.counter.should eq(3)
      end

      it "adds a looping image stream for a file margin fill" do
        path = "./temp/builder-margin.png"
        CrImage::PNG.write(path, CrImage.rgba(2, 2))

        style = StyleOptions.new(margin_fill: path, margin: 10)
        builder = StreamBuilder.new(2, "./temp", style).with_margin

        builder.args.should eq(["-loop", "1", "-i", path])
        builder.margin_stream.should eq(2)
        File.delete(path)
      end

      it "draws and adds the window bar stream" do
        style = StyleOptions.new(window_bar: "Colorful", window_bar_size: 30, window_bar_color: "#171717")
        builder = StreamBuilder.new(2, "./temp", style).with_bar

        builder.args.first(2).should eq(["-i", "./temp/bar.png"])
        File.exists?("./temp/bar.png").should be_true
        builder.bar_stream.should eq(2)
        builder.counter.should eq(3)
        File.delete("./temp/bar.png")
      end

      it "draws the border radius mask at bar height when a bar is present" do
        style = StyleOptions.new(
          width: 40, height: 30, border_radius: 4,
          window_bar: "Rings", window_bar_size: 10, window_bar_color: "#171717"
        )
        builder = StreamBuilder.new(2, "./temp", style).with_corner

        builder.args.first(2).should eq(["-i", "./temp/mask.png"])
        # Term height is 30 - 10 (bar) = 20, and the mask covers the bar too.
        mask = CrImage::PNG.read("./temp/mask.png")
        mask.bounds.max.y.should eq(30)
        mask.bounds.max.x.should eq(40)
        File.delete("./temp/mask.png")
      end

      it "adds the encoder flags" do
        style = StyleOptions.new
        StreamBuilder.new(2, "./temp", style).with_mp4.args.should eq(
          ["-vcodec", "libx264", "-pix_fmt", "yuv420p", "-an", "-crf", "20"]
        )
        StreamBuilder.new(2, "./temp", style).with_webm.args.should eq(
          ["-pix_fmt", "yuv420p", "-an", "-crf", "30", "-b:v", "0"]
        )
      end
    end

    describe ".build_ff_opts" do
      it "builds GIF arguments with the palette filter" do
        video = builder_video_options(gif: "./temp/out.gif")
        args = Vhs.build_ff_opts(video, "./temp/out.gif")

        args.first(7).should eq([
          "-y", "-r", "50", "-start_number", "1",
          "-i", "./temp/frames/frame-text-%05d.png",
        ])
        args.should contain("./temp/frames/frame-cursor-%05d.png")
        args.last(3).should eq(["-map", "[palette]", "./temp/out.gif"])
        args[args.index!("-filter_complex") + 1].should contain("palettegen")
      end

      it "builds MP4 arguments with the libx264 flags and no palette stage" do
        video = builder_video_options(mp4: "./temp/out.mp4")
        args = Vhs.build_ff_opts(video, "./temp/out.mp4")

        args.should contain("-vcodec")
        args.should contain("libx264")
        args.last(3).should eq(["-map", "[padded]", "./temp/out.mp4"])
        args[args.index!("-filter_complex") + 1].should_not contain("palettegen")
      end

      it "builds WebM arguments with the webm encoder flags" do
        video = builder_video_options(webm: "./temp/out.webm")
        args = Vhs.build_ff_opts(video, "./temp/out.webm")

        args.should contain("-b:v")
        args.last(3).should eq(["-map", "[padded]", "./temp/out.webm"])
      end

      it "adds the margin, bar, and corner streams when styled" do
        style = StyleOptions.new(
          width: 1200, height: 600, padding: 60, background_color: "#171717",
          window_bar: "Colorful", window_bar_size: 30, window_bar_color: "#171717",
          border_radius: 12, margin_fill: "#2b2b2b", margin: 10
        )
        video = VideoOptions.new(framerate: 50, playback_speed: 1.0, input: "./temp/frames",
          output: VideoOutputs.new(gif: "./temp/out.gif"), style: style)

        args = Vhs.build_ff_opts(video, "./temp/out.gif")
        filter = args[args.index!("-filter_complex") + 1]

        filter.should contain("[2]scale=1200:600[bg]")
        filter.should contain("[3]loop=-1[loopbar]")
        filter.should contain("[4]loop=-1[loopmask]")
        File.delete("./temp/frames/bar.png") if File.exists?("./temp/frames/bar.png")
        File.delete("./temp/frames/mask.png") if File.exists?("./temp/frames/mask.png")
      end
    end

    describe ".make_gif / .make_mp4 / .make_webm" do
      it "returns nil for outputs that are not configured" do
        video = builder_video_options
        Vhs.make_gif(video).should be_nil
        Vhs.make_mp4(video).should be_nil
        Vhs.make_webm(video).should be_nil
        Vhs.make_media(video, "").should be_nil
      end

      it "builds the command for each configured output" do
        video = builder_video_options(gif: "./temp/out.gif", mp4: "./temp/out.mp4", webm: "./temp/out.webm")

        Vhs.make_gif(video).try(&.last).should eq("./temp/out.gif")
        Vhs.make_mp4(video).try(&.last).should eq("./temp/out.mp4")
        Vhs.make_webm(video).try(&.last).should eq("./temp/out.webm")
        Vhs.make_mp4(video).try(&.includes?("libx264")).should be_true
        Vhs.make_webm(video).try(&.includes?("-b:v")).should be_true
      end
    end

    describe "FFmpegRenderer.screenshot_commands" do
      it "builds one ffmpeg invocation per deferred screenshot" do
        screenshot = ScreenshotOptions.new(
          input: "./temp/frames",
          style: StyleOptions.new(width: 1200, height: 600, padding: 60, background_color: "#171717")
        )
        screenshot.enable_frame_capture("./temp/shot-a.png")
        screenshot.make_screenshot(3)
        screenshot.enable_frame_capture("./temp/shot-b.png")
        screenshot.make_screenshot(9)

        commands = FFmpegRenderer.screenshot_commands(screenshot)
        commands.size.should eq(2)

        by_suffix = commands.to_h { |args| {args.last, args} }
        by_suffix.keys.should contain("./temp/shot-a.png")
        by_suffix.keys.should contain("./temp/shot-b.png")
        by_suffix["./temp/shot-a.png"].should contain("./temp/frames/frame-text-00003.png")
        by_suffix["./temp/shot-b.png"].should contain("./temp/frames/frame-text-00009.png")
      end
    end

    describe ".build_screenshot_opts" do
      it "uses the single text and cursor frames as inputs" do
        screenshot = ScreenshotOptions.new(
          input: "./temp/frames",
          style: StyleOptions.new(width: 1200, height: 600, padding: 60, background_color: "#171717")
        )

        args = Vhs.build_screenshot_opts(screenshot, "./temp/shot.png", 7)

        args.first(5).should eq([
          "-y", "-i",
          "./temp/frames/frame-text-00007.png",
          "-i",
          "./temp/frames/frame-cursor-00007.png",
        ])
        args.last(3).should eq(["-map", "[padded]", "./temp/shot.png"])
      end
    end
  end
end
