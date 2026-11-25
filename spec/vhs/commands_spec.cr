require "../spec_helper"

module Vhs
  # Characterization specs for the helpers behind main.go's `new`, `themes`, and
  # `validate` commands. The CLI wrappers stay thin so these cover the behavior.
  describe ".demo_tape" do
    it "points the output at the given name" do
      tape = Vhs.demo_tape("demo")

      tape.should contain("Output demo.gif")
      tape.should_not contain("examples/demo.gif")
    end

    it "replaces only the first output line" do
      Vhs.demo_tape("demo").scan("Output demo.gif").size.should eq(1)
    end
  end

  describe ".new_tape" do
    it "writes a scaffolded tape and returns its name" do
      dir = File.join("temp", "new_tape_spec")
      Dir.mkdir_p(dir)

      file = Vhs.new_tape("demo", dir: dir)

      file.should eq(File.join(dir, "demo.tape"))
      File.read(file).should contain("Output demo.gif")
    end

    it "does not double a .tape suffix" do
      dir = File.join("temp", "new_tape_suffix_spec")
      Dir.mkdir_p(dir)

      Vhs.new_tape("demo.tape", dir: dir).should eq(File.join(dir, "demo.tape"))
    end

    it "truncates an existing tape like os.Create" do
      dir = File.join("temp", "new_tape_truncate_spec")
      Dir.mkdir_p(dir)
      file = File.join(dir, "demo.tape")
      File.write(file, "stale content")

      Vhs.new_tape("demo", dir: dir)

      File.read(file).should_not contain("stale content")
      File.read(file).should contain("# VHS documentation")
    end
  end

  describe ".theme_list" do
    it "lists one theme per line" do
      names = Vhs.sorted_theme_names
      pending! "themes.json is not available" if names.empty?

      listing = Vhs.theme_list
      listing.lines.map(&.chomp).should eq(names)
      listing.should_not contain("`")
    end

    it "renders markdown when asked" do
      pending! "themes.json is not available" if Vhs.sorted_theme_names.empty?

      lines = Vhs.theme_list(markdown: true).split('\n')

      lines[0].should eq("# Themes")
      lines[1].should eq("")
      lines[2].should eq("* `#{Vhs.sorted_theme_names.first}`")
    end
  end

  describe ".validate_tape" do
    it "reports no errors for a valid tape" do
      Vhs.validate_tape("Output demo.gif\nSet FontSize 22\nSleep 1s\n").should be_empty
    end

    it "reports the parser errors for an invalid tape" do
      errors = Vhs.validate_tape("NotACommand foo\n")

      errors.should_not be_empty
      errors.first.message.should contain("Invalid command")
    end

    it "reports an unknown setting" do
      errors = Vhs.validate_tape("Set Nope 1\n")

      errors.should_not be_empty
      errors.first.message.should contain("Unknown setting")
    end
  end
end
