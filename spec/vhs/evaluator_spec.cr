require "../spec_helper"
require "file_utils"

module Vhs
  describe "evaluator" do
    describe ".evaluate" do
      it "executes simple tape without errors" do
        tape = <<-TAPE
        Output test.gif
        Sleep 0.1s
        TAPE

        errors = Vhs.evaluate(tape)
        errors.should be_empty
      end

      it "executes tape with Type command" do
        tape = <<-TAPE
        Output test.gif
        Type "Hello"
        Sleep 0.1s
        TAPE

        errors = Vhs.evaluate(tape)
        errors.should be_empty
      end

      it "returns error for unknown theme" do
        tape = <<-TAPE
        Output test.gif
        Set Theme "UnknownTheme"
        Sleep 0.1s
        TAPE

        errors = Vhs.evaluate(tape)
        errors.should_not be_empty
        errors.any?(Vhs::ThemeNotFoundError).should be_true
      end

      it "returns no error for valid theme" do
        tape = <<-TAPE
        Output test.gif
        Set Theme "Andromeda"
        Sleep 0.1s
        TAPE

        errors = Vhs.evaluate(tape)
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

        errors = Vhs.evaluate(tape)
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

        errors = Vhs.evaluate(tape)
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

        errors = Vhs.evaluate(tape)
        errors.should be_empty
        File.delete(path) if File.exists?(path)
      end

      it "returns error for Screenshot without .png extension" do
        tape = <<-TAPE
        Output test.gif
        Screenshot "test.jpg"
        TAPE

        errors = Vhs.evaluate(tape)
        errors.should_not be_empty
      end

      pending "executes Wait command"

      it "executes Ctrl command" do
        tape = <<-TAPE
        Output test.gif
        Ctrl+C
        Sleep 0.1s
        TAPE

        errors = Vhs.evaluate(tape)
        errors.should be_empty
      end

      it "executes Alt command" do
        tape = <<-TAPE
        Output test.gif
        Alt+.
        Sleep 0.1s
        TAPE

        errors = Vhs.evaluate(tape)
        errors.should be_empty
      end

      pending "executes Shift command"

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

        errors = Vhs.evaluate(tape)
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

        errors = Vhs.evaluate(tape)
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

          errors = Vhs.evaluate(tape)
          errors.should be_empty
          File.delete(src_path)
        end

        it "returns error for missing tape" do
          src_path = File.join(temp_dir, "missing.tape")
          tape = <<-TAPE
          Output test.gif
          Source #{src_path}
          TAPE

          errors = Vhs.evaluate(tape)
          errors.should_not be_empty
        end

        it "returns error for non-.tape extension" do
          src_path = File.join(temp_dir, "source.txt")
          File.write(src_path, "")
          tape = <<-TAPE
          Output test.gif
          Source #{src_path}
          TAPE

          errors = Vhs.evaluate(tape)
          errors.should_not be_empty
          File.delete(src_path)
        end
      end
    end
  end
end
