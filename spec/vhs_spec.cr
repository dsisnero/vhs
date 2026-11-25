require "./spec_helper"

describe Vhs do
  describe ".default_vhs_options" do
    it "matches upstream DefaultVHSOptions" do
      options = Vhs.default_vhs_options

      options.font_family.should eq(Vhs::DEFAULT_FONT_FAMILY)
      options.font_size.should eq(22)
      options.letter_spacing.should eq(1.0)
      options.line_height.should eq(1.0)
      options.typing_speed.should eq(50.milliseconds)
      options.shell.should eq(Vhs::SHELLS[Vhs::DEFAULT_SHELL])
      options.theme.should eq(Vhs::DEFAULT_THEME)
      options.cursor_blink?.should be_true
      options.wait_timeout.should eq(15.seconds)
      options.wait_pattern.should eq(/>$/)
      options.loop_offset.should eq(0.0)
      options.test.output.should eq("")
    end

    it "wires the style through video and screenshot options" do
      options = Vhs.default_vhs_options

      options.video.style.should eq(options.style)
      options.screenshot.input.should eq(options.video.input)
      options.screenshot.style.should eq(options.style)
      options.style.width.should eq(Vhs::DEFAULT_WIDTH)
      options.style.height.should eq(Vhs::DEFAULT_HEIGHT)
    end

    it "keeps the upstream font fallback chain" do
      Vhs::DEFAULT_FONT_FAMILY.should start_with("JetBrains Mono")
      Vhs::DEFAULT_FONT_FAMILY.should contain("DejaVu Sans Mono")
      Vhs::DEFAULT_FONT_FAMILY.should end_with("Apple Symbols")
    end
  end

  describe ".default_video_options" do
    it "matches upstream DefaultVideoOptions" do
      video = Vhs.default_video_options

      video.framerate.should eq(50)
      video.playback_speed.should eq(1.0)
      video.max_colors.should eq(256)
      video.starting_frame.should eq(1)
      video.input.should_not be_empty
      video.output.gif.should eq("")
      video.output.mp4.should eq("")
      video.output.webm.should eq("")
      video.output.frames.should eq("")
      video.style.width.should eq(Vhs::DEFAULT_WIDTH)
    end
  end

  describe "Go zero values" do
    it "leaves StyleOptions at the Go zero value" do
      style = Vhs::StyleOptions.new

      style.width.should eq(0)
      style.height.should eq(0)
      style.padding.should eq(0)
      style.window_bar_size.should eq(0)
      style.background_color.should eq("")
      style.margin_fill.should eq("")
    end

    it "leaves the wait pattern unset until default options are applied" do
      Vhs::Options.new.wait_pattern.should be_nil
      Vhs.default_vhs_options.wait_pattern.should eq(/>$/)
    end
  end

  describe "VHS.new" do
    it "seeds the instance with the default options" do
      vhs = Vhs::VHS.new

      vhs.options.font_size.should eq(Vhs.default_vhs_options.font_size)
      vhs.options.theme.should eq(Vhs::DEFAULT_THEME)
      vhs.recording?.should be_true
      vhs.started?.should be_false
      vhs.errors.should be_empty
    end

    it "starts out recording, like upstream New" do
      Vhs::VHS.new.recording?.should be_true
    end
  end

  describe "Shell" do
    it "matches the upstream shell defaults" do
      bash = Vhs::SHELLS["bash"]
      bash.command.should eq(["bash", "--noprofile", "--norc", "--login", "+o", "history"])
      bash.env.should eq(["PS1=\\[\\e[38;2;90;86;224m\\]> \\[\\e[0m\\]", "BASH_SILENCE_DEPRECATION_WARNING=1"])
    end

    it "defaults to the upstream shell names" do
      Vhs::SHELLS.keys.should contain("bash")
      Vhs::SHELLS.keys.should contain("zsh")
      Vhs::SHELLS.keys.should contain("fish")
      Vhs::Shell.new.command.should eq(["sh"])
    end
  end

  describe "Theme" do
    it "serializes to the xterm.js JSON shape like upstream Theme.String" do
      json = Vhs::DEFAULT_THEME.to_json

      json.should contain(%("background":"#{Vhs::BACKGROUND}"))
      json.should contain(%("brightBlack":"#{Vhs::BRIGHT_BLACK}"))
      json.should contain(%("cursorAccent":"#{Vhs::BACKGROUND}"))
      Vhs::Theme.from_json(json).should eq(Vhs::DEFAULT_THEME)
    end
  end

  describe ".default_test_options" do
    it "matches upstream DefaultTestOptions" do
      Vhs.default_test_options.output.should eq("out.test")
    end
  end

  describe "TestOptions" do
    it "matches the Go zero value used by DefaultVHSOptions" do
      Vhs::TestOptions.new.output.should eq("")
    end
  end
end
