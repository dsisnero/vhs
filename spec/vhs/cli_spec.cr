require "../spec_helper"

module Vhs::CLI
  # Characterization specs for upstream main.go's evaluator option: the -o paths
  # and the GIF that gets published.
  describe OutputOverride do
    it "applies each -o path to the output with the same extension" do
      override = OutputOverride.new(["/tmp/out.gif", "/tmp/out.webm", "/tmp/out.mp4"])
      vhs = Vhs::VHS.new
      vhs.options = Vhs.default_vhs_options

      override.option.call(vhs)

      vhs.options.video.output.gif.should eq("/tmp/out.gif")
      vhs.options.video.output.webm.should eq("/tmp/out.webm")
      vhs.options.video.output.mp4.should eq("/tmp/out.mp4")
      override.publish_file.should eq("/tmp/out.gif")
    end

    it "ignores outputs with an unknown extension" do
      override = OutputOverride.new(["/tmp/out.txt"])
      vhs = Vhs::VHS.new
      vhs.options = Vhs.default_vhs_options
      vhs.options.video.output.gif = "tape.gif"

      override.option.call(vhs)

      vhs.options.video.output.gif.should eq("tape.gif")
    end

    it "keeps the tape's own output when no -o is given" do
      override = OutputOverride.new([] of String)
      vhs = Vhs::VHS.new
      vhs.options = Vhs.default_vhs_options
      vhs.options.video.output.gif = "tape.gif"

      override.option.call(vhs)

      vhs.options.video.output.gif.should eq("tape.gif")
      override.publish_file.should eq("tape.gif")
    end
  end
end
