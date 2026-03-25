require "../spec_helper"
require "../../src/vhs/png_renderer"

module Vhs
  describe PNGRenderer do
    it "renders simple buffer to PNG file" do
      # Create a 2x2 buffer with characters
      buffer = [
        ['H', 'i'],
        ['!', ' '],
      ]

      output_path = File.tempname(suffix: ".png")
      begin
        PNGRenderer.render(buffer, output_path, font_size: 24)
        File.exists?(output_path).should be_true
        # TODO: verify PNG dimensions
      ensure
        File.delete(output_path) if File.exists?(output_path)
      end
    end

    it "renders with a comma-separated font fallback list" do
      buffer = [
        ['O', 'K'],
      ]

      output_path = File.tempname(suffix: ".png")
      font_family = "JetBrains Mono,DejaVu Sans Mono,Menlo,monospace"
      begin
        PNGRenderer.render(buffer, output_path, font_family: font_family, font_size: 24)
        File.exists?(output_path).should be_true
      ensure
        File.delete(output_path) if File.exists?(output_path)
      end
    end
  end
end
