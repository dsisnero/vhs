require "../spec_helper"
require "file_utils"

module Vhs
  class FakeWaitVHS < Vhs::VHS
    property line_value : String
    property screen_value : Array(String)

    def initialize(@line_value : String, @screen_value : Array(String), options : Vhs::Options)
      super()
      @options = options
    end

    def current_line : String
      @line_value
    end

    def buffer : Array(String)
      @screen_value
    end
  end

  describe "evaluator" do
    describe ".evaluate" do
      it "executes simple tape without errors" do
        tape = <<-TAPE
        Output test.gif
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
      end

      it "executes tape with Type command" do
        tape = <<-TAPE
        Output test.gif
        Type "Hello"
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
      end

      it "returns error for unknown theme" do
        tape = <<-TAPE
        Output test.gif
        Set Theme "UnknownTheme"
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should_not be_empty
        errors.any?(Vhs::ThemeNotFoundError).should be_true
      end

      it "returns no error for valid theme" do
        tape = <<-TAPE
        Output test.gif
        Set Theme "Andromeda"
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
      end

      it "executes Hide and Show commands" do
        tape = <<-TAPE
        Output test.gif
        Hide
        Sleep 0.1s
        Show
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
      end

      it "executes Copy and Paste commands" do
        tape = <<-TAPE
        Output test.gif
        Copy "Hello"
        Sleep 0.1s
        Paste
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
      end

      it "executes Screenshot command with .png extension" do
        FileUtils.mkdir_p("./temp")
        path = File.join("./temp", "screenshot.png")
        tape = <<-TAPE
        Output test.gif
        Screenshot "#{path}"
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
        File.delete(path) if File.exists?(path)
      end

      it "returns error for Screenshot without .png extension" do
        tape = <<-TAPE
        Output test.gif
        Screenshot "test.jpg"
        TAPE

        errors = evaluate_without_render(tape)
        errors.should_not be_empty
      end

      it "executes Wait command with the default line scope and regex" do
        options = Vhs.default_vhs_options
        options.wait_pattern = /prompt/
        v = FakeWaitVHS.new("prompt", ["prompt"], options)

        cmd = Vhs::Parser::Command.new(Vhs::Token::WAIT, "", "Line")
        Vhs.execute_wait(cmd, v).should be_nil
      end

      it "executes Ctrl command" do
        tape = <<-TAPE
        Output test.gif
        Ctrl+C
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
      end

      it "executes Alt command" do
        tape = <<-TAPE
        Output test.gif
        Alt+.
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
      end

      it "executes Shift command" do
        tape = <<-TAPE
        Output test.gif
        Type "cat"
        Enter
        Shift+A
        Enter
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        errors.should be_empty
      end

      it "executes key commands" do
        tape = <<-TAPE
        Output test.gif
        Backspace 2
        Delete 1
        Insert 1
        Up 1
        Down 1
        Left 1
        Right 1
        Space
        Tab
        Escape
        PageUp 1
        PageDown 1
        Sleep 0.1s
        TAPE

        errors = evaluate_without_render(tape)
        if errors.any?
          puts "Parser errors:"
          errors.each do |err|
            puts "  #{err.class}: #{err.message}"
            if err.is_a?(Vhs::InvalidSyntaxError)
              err.errors.each do |perr|
                puts "    #{perr}"
              end
            end
          end
        end
        errors.should be_empty
      end

      it "returns error for invalid setting" do
        tape = <<-TAPE
        Output test.gif
        Set InvalidSetting 123
        TAPE

        errors = evaluate_without_render(tape)
        errors.should_not be_empty
        if error = errors.first
          puts "Error class: #{error.class}"
          puts "Error message: #{error.message}"
        end
      end

      describe "Source command" do
        temp_dir = "./temp"
        FileUtils.mkdir_p(temp_dir)

        it "executes source with existing tape" do
          src_path = File.join(temp_dir, "source.tape")
          File.write(src_path, "Output test.gif\nSleep 0.1s")
          tape = <<-TAPE
          Output test.gif
          Source #{src_path}
          TAPE

          errors = evaluate_without_render(tape)
          errors.should be_empty
          File.delete(src_path)
        end

        it "returns error for missing tape" do
          src_path = File.join(temp_dir, "missing.tape")
          tape = <<-TAPE
          Output test.gif
          Source #{src_path}
          TAPE

          errors = evaluate_without_render(tape)
          errors.should_not be_empty
        end

        it "returns error for non-.tape extension" do
          src_path = File.join(temp_dir, "source.txt")
          File.write(src_path, "")
          tape = <<-TAPE
          Output test.gif
          Source #{src_path}
          TAPE

          errors = evaluate_without_render(tape)
          errors.should_not be_empty
          File.delete(src_path)
        end
      end
    end

    describe "non-style settings" do
      it "applies every remaining Set command to the options" do
        tape = <<-TAPE
        Set Shell bash
        Set FontFamily "JetBrains Mono"
        Set FontSize 18
        Set LetterSpacing 2
        Set LineHeight 1.5
        Set Framerate 25
        Set PlaybackSpeed 2.5
        Set TypingSpeed 120ms
        Set WaitTimeout 1m
        Set WaitPattern /ready>/
        Set CursorBlink false
        Output test.gif
        Sleep 0.1s
        TAPE

        inspected = false
        inspect_options = ->(v : VHS) do
          inspected = true
          options = v.options

          options.shell.should eq(SHELLS["bash"])
          options.font_family.should eq("JetBrains Mono")
          options.font_size.should eq(18)
          options.letter_spacing.should eq(2.0)
          options.line_height.should eq(1.5)
          options.video.framerate.should eq(25)
          options.video.playback_speed.should eq(2.5)
          options.typing_speed.should eq(120.milliseconds)
          options.wait_timeout.should eq(1.minute)
          options.wait_pattern.should eq(/ready>/)
          options.cursor_blink?.should be_false

          options.video.output = VideoOutputs.new
          options.screenshot.screenshots.clear
          nil
        end

        Vhs.evaluate(tape, IO::Memory.new, inspect_options, drop_outputs_option).should be_empty
        inspected.should be_true
      end

      it "rejects invalid setting values" do
        invalid_tapes = [
          "Set Shell nope\nOutput test.gif",
          "Set FontSize 0\nOutput test.gif",
          "Set LetterSpacing 0\nOutput test.gif",
          "Set LineHeight -1\nOutput test.gif",
          "Set Framerate 0\nOutput test.gif",
          "Set PlaybackSpeed 0\nOutput test.gif",
          "Set TypingSpeed nope\nOutput test.gif",
          "Set WaitTimeout nope\nOutput test.gif",
          "Set WaitPattern [\nOutput test.gif",
        ]

        invalid_tapes.each do |tape|
          Vhs.evaluate(tape, IO::Memory.new, drop_outputs_option).should_not be_empty
        end
      end
    end

    describe "env, loop offset, and require" do
      it "applies Env to the process environment like upstream" do
        tape = <<-TAPE
        Env VHS_SPEC_ENV seen
        Output test.gif
        Sleep 0.1s
        TAPE

        begin
          Vhs.evaluate(tape, IO::Memory.new, drop_outputs_option).should be_empty
          ENV["VHS_SPEC_ENV"]?.should eq("seen")
        ensure
          ENV.delete("VHS_SPEC_ENV")
        end
      end

      it "parses LoopOffset percentages" do
        tape = <<-TAPE
        Set LoopOffset 60.4%
        Output test.gif
        Sleep 0.1s
        TAPE

        seen = 0.0
        inspect_offset = ->(v : VHS) do
          seen = v.options.loop_offset
          v.options.video.output = VideoOutputs.new
          nil
        end

        Vhs.evaluate(tape, IO::Memory.new, inspect_offset, drop_outputs_option).should be_empty
        seen.should eq(60.4)
      end

      it "requires a binary that exists in PATH" do
        present = "Require sh\nOutput test.gif\nSleep 0.1s"
        Vhs.evaluate(present, IO::Memory.new, drop_outputs_option).should be_empty

        missing = "Require definitely-not-a-real-binary\nOutput test.gif"
        errors = Vhs.evaluate(missing, IO::Memory.new, drop_outputs_option)
        errors.size.should eq(1)
        errors.first.message.to_s.should contain("not found in PATH")
      end
    end

    describe "style settings" do
      it "propagates SET style commands to the video and screenshot options" do
        tape = <<-TAPE
        Output test.gif
        Set Width 400
        Set Height 200
        Set Padding 10
        Set Margin 12
        Set MarginFill "#2b2b2b"
        Set WindowBar Colorful
        Set WindowBarSize 20
        Set BorderRadius 8
        Sleep 0.1s
        TAPE

        inspected = false
        inspect_style = ->(v : VHS) do
          inspected = true
          options = v.options
          options.style.width.should eq(400)
          options.style.height.should eq(200)
          options.style.padding.should eq(10)
          options.style.margin.should eq(12)
          options.style.margin_fill.should eq("#2b2b2b")
          options.style.window_bar.should eq("Colorful")
          options.style.window_bar_size.should eq(20)
          options.style.border_radius.should eq(8)

          # The renderers read their own copy; upstream shares one StyleOptions.
          options.video.style.should eq(options.style)
          options.screenshot.style.should eq(options.style)

          options.video.output = VideoOutputs.new
          options.screenshot.screenshots.clear
          nil
        end

        Vhs.evaluate(tape, IO::Memory.new, inspect_style, drop_outputs_option).should be_empty
        inspected.should be_true
      end
    end

    describe "EvaluatorOption" do
      it "runs after the tape's commands have been executed" do
        tape = <<-TAPE
        Set Theme "Catppuccin Latte"
        Output test.gif
        Sleep 0.15s
        TAPE

        seen_theme = ""
        option = ->(v : VHS) do
          seen_theme = v.options.theme.name
          nil
        end

        errors = Vhs.evaluate(tape, IO::Memory.new, option, drop_outputs_option)

        errors.should be_empty
        seen_theme.should eq("Catppuccin Latte")
      end

      it "can redirect the output paths before rendering" do
        tape = <<-TAPE
        Output test.gif
        Sleep 0.15s
        TAPE

        captured = ""
        redirect = ->(v : VHS) do
          v.options.video.output.gif = "redirected.gif"
          nil
        end
        capture = ->(v : VHS) do
          captured = v.options.video.output.gif
          nil
        end

        Vhs.evaluate(tape, IO::Memory.new, redirect, capture, drop_outputs_option).should be_empty
        captured.should eq("redirected.gif")
      end

      it "applies multiple options in order" do
        tape = <<-TAPE
        Output test.gif
        Sleep 0.15s
        TAPE

        calls = [] of String
        first = ->(_v : VHS) do
          calls << "first"
          nil
        end
        second = ->(_v : VHS) do
          calls << "second"
          nil
        end

        Vhs.evaluate(tape, IO::Memory.new, first, second, drop_outputs_option).should be_empty
        calls.should eq(["first", "second"])
      end
    end
  end
end
