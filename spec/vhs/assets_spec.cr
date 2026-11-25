require "../spec_helper"

module Vhs
  # The port bakes upstream's `//go:embed` data (themes.json, examples/demo.tape)
  # into the binary instead of reading the vendor checkout at runtime.
  describe Assets do
    it "bakes the theme list and the demo tape" do
      Assets.get?("themes.json").should_not be_nil
      Assets.get?("demo.tape").should_not be_nil
    end

    it "does not bake exFAT AppleDouble sidecars" do
      # `bake_folder` skips dotfiles, which is what keeps this exFAT checkout's
      # `._*` sidecars out of the binary.
      Assets.get?("._themes.json").should be_nil
      Assets.get?("._demo.tape").should be_nil
    end

    it "keeps themes.json identical to upstream's" do
      upstream = File.join("vendor", "vhs", "themes.json")
      pending! "vendor/vhs is not checked out" unless File.exists?(upstream)

      Assets.get("themes.json").read.should eq(File.read(upstream))
    end

    it "keeps the demo tape identical to upstream's" do
      upstream = File.join("vendor", "vhs", "examples", "demo.tape")
      pending! "vendor/vhs is not checked out" unless File.exists?(upstream)

      Assets.get("demo.tape").read.should eq(File.read(upstream))
    end

    it "decodes every theme from the baked data" do
      # The theme count upstream's own test asserts.
      Vhs.sorted_theme_names.size.should eq(348)
    end
  end
end
