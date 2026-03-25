require "crimage"
require "crimage/freetype"
require "stumpy_png"

module Vhs
  # PNGRenderer renders terminal buffer to PNG images.
  module PNGRenderer
    extend self

    MONOSPACE_FONTCONFIG_SPACING = "100"

    # Resolves font family name to a font file path.
    # Tries fc-match first, falls back to bundled Roboto font.
    private def resolve_font_path(font_family : String) : String
      # If font_family looks like a file path (ends with .ttf/.otf or absolute path)
      if font_family.ends_with?(".ttf") || font_family.ends_with?(".otf") || font_family.starts_with?("/")
        if File.exists?(font_family)
          return font_family
        end
      end

      candidates = font_family.split(',').map(&.strip).reject(&.empty?)
      candidates = [font_family] if candidates.empty?

      # Prefer the first monospace system font from the fallback list.
      candidates.each do |candidate|
        file_path, spacing = match_font(candidate)
        if file_path && spacing == MONOSPACE_FONTCONFIG_SPACING
          return file_path
        end
      end

      # Fall back to the first resolvable font if no monospace match was found.
      candidates.each do |candidate|
        file_path, _spacing = match_font(candidate)
        return file_path if file_path
      end

      # Fallback to bundled Roboto font (for development)
      bundled_path = File.expand_path("../../lib/crimage/spec/testdata/fonts/Roboto/Roboto-Bold.ttf", __DIR__)
      if File.exists?(bundled_path)
        return bundled_path
      end

      raise "Could not resolve font family '#{font_family}'. Install fontconfig or provide full font path."
    end

    private def match_font(font_family : String) : {String?, String?}
      output = IO::Memory.new
      error = IO::Memory.new
      cache_dir = File.expand_path("../../temp/fontconfig-cache", __DIR__)
      Dir.mkdir_p(cache_dir)
      status = Process.run(
        "fc-match",
        ["-f", "%{file}\n%{spacing}\n", font_family],
        env: {"XDG_CACHE_HOME" => cache_dir},
        output: output,
        error: error
      )

      return {nil, nil} unless status.success?

      lines = output.to_s.lines.map(&.strip)
      file_path = lines[0]?.presence
      spacing = lines[1]?.presence
      return {nil, nil} unless file_path && File.exists?(file_path)

      {file_path, spacing}
    end

    # Renders terminal buffer to PNG file.
    # @param buffer [Array(Array(Char))] 2D array of characters (rows x columns)
    # @param output_path [String] path to save PNG
    # @param font_family [String] font family name (not yet used)
    # @param font_size [Int32] font size in points
    # @param letter_spacing [Float64] additional spacing between characters
    # @param line_height [Float64] line height multiplier
    # @param foreground [String] hex color for text
    # @param background [String] hex color for background
    def render(buffer : Array(Array(Char)), output_path : String,
               font_family : String = "DejaVu Sans Mono", font_size : Int32 = 22,
               letter_spacing : Float64 = 1.0, line_height : Float64 = 1.0,
               foreground : String = "#dddddd", background : String = "#171717")
      # Load font using font family resolution
      font_path = resolve_font_path(font_family)
      unless File.exists?(font_path)
        raise "Font file not found: #{font_path}"
      end

      font = FreeType::TrueType.load(font_path)
      face = FreeType::TrueType.new_face(font, font_size.to_f64)

      # Compute cell dimensions
      metrics = face.metrics
      # height includes ascent + descent (line height)
      line_height_px = (metrics.height.to_i / 64.0 * line_height).round.to_i
      # advance width for 'M' as cell width
      advance, ok = face.glyph_advance('M')
      unless ok
        advance = face.glyph_advance('A')[0] # fallback
      end
      cell_width = (advance.to_i / 64.0 * letter_spacing).round.to_i

      rows = buffer.size
      cols = buffer[0]?.try(&.size) || 0

      # Image dimensions
      img_width = cols * cell_width
      img_height = rows * line_height_px

      # Create image with background color
      bg_color = CrImage::Color.parse(background)
      image = CrImage.rgba(img_width, img_height)
      image.fill(bg_color)

      # Foreground color
      fg_color = CrImage::Color.parse(foreground)
      src = CrImage::Uniform.new(fg_color)

      # Precompute ascent in pixels
      ascent_px = metrics.ascent.floor

      # Draw each character
      buffer.each_with_index do |row, y|
        row.each_with_index do |char, x|
          next if char == ' ' # skip spaces

          # Baseline position (in pixels)
          baseline_x = x * cell_width
          baseline_y = y * line_height_px + ascent_px

          dot = CrImage::Math::Fixed::Point26_6.new(
            CrImage::Math::Fixed::Int26_6[baseline_x * 64],
            CrImage::Math::Fixed::Int26_6[baseline_y * 64]
          )
          drawer = CrImage::Font::Drawer.new(image, src, face, dot)
          drawer.draw(char.to_s)
        end
      end

      # Save PNG
      CrImage::PNG.write(output_path, image)
    end
  end
end
