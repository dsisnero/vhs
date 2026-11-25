require "crimage"

module Vhs
  # Draw generates the PNG resources the renderer overlays with ffmpeg: the
  # window bar image and the border-radius alpha mask.
  #
  # Ported from upstream draw.go. The Go version composites through image/draw
  # masks; the port applies the same alpha masks directly, which is equivalent
  # because every source here is opaque and each fill happens over a known base.
  module Draw
    extend self

    WHITE = 0xFF_u8
    BLACK = 0x17_u8

    HALF_PIXEL      = 0.5
    DOUBLING_FACTOR =   2

    BAR_TO_DOT_RATIO        = 6
    BAR_TO_DOT_BORDER_RATIO = 5

    COLORFUL_DOT_A = CrImage::Color::RGBA.new(0xFF, 0x4F, 0x4D, 0xFF)
    COLORFUL_DOT_B = CrImage::Color::RGBA.new(0xFE, 0xBB, 0x00, 0xFF)
    COLORFUL_DOT_C = CrImage::Color::RGBA.new(0x00, 0xCC, 0x1D, 0xFF)
    RING_COLOR     = CrImage::Color::RGBA.new(0x33, 0x33, 0x33, 0xFF)

    def double(i : Int32) : Int32
      i * DOUBLING_FACTOR
    end

    def half(i : Int32) : Int32
      i // DOUBLING_FACTOR
    end

    # Alpha mask for a circle, mirroring upstream's circle type. The radius is
    # shrunk by one so the outermost pixels can be antialiased.
    struct Circle
      getter point : {Int32, Int32}
      getter radius : Int32

      def initialize(@point : {Int32, Int32}, @radius : Int32)
      end

      # Bounds mirrors upstream's image.Rectangle for the circle.
      def bounds : Tuple(Int32, Int32, Int32, Int32)
        {point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius}
      end

      def alpha_at(x : Int32, y : Int32) : UInt8
        xx = (x - point[0]).to_f64 + HALF_PIXEL
        yy = (y - point[1]).to_f64 + HALF_PIXEL
        rr = radius.to_f64 - 1
        dist = Math.sqrt(xx * xx + yy * yy) - rr

        if dist < 0
          WHITE
        elsif dist <= 1
          ((1 - dist) * WHITE).to_u8
        else
          0_u8
        end
      end
    end

    # Alpha mask for an axis-aligned rectangle, mirroring upstream's rect type.
    struct Rectangle
      getter pa : {Int32, Int32}
      getter pb : {Int32, Int32}

      def initialize(@pa : {Int32, Int32}, @pb : {Int32, Int32})
      end

      # Bounds mirrors upstream's image.Rectangle for the rect.
      def bounds : Tuple(Int32, Int32, Int32, Int32)
        {pa[0], pa[1], pb[0], pb[1]}
      end

      def alpha_at(x : Int32, y : Int32) : UInt8
        if x >= pa[0] && x < pb[0] && y >= pa[1] && y < pb[1]
          WHITE
        else
          0_u8
        end
      end
    end

    # Alpha mask for a rectangle with rounded corners, mirroring upstream's
    # roundedrect type.
    struct RoundedRectangle
      getter pa : {Int32, Int32}
      getter pb : {Int32, Int32}
      getter radius : Int32

      def initialize(@pa : {Int32, Int32}, @pb : {Int32, Int32}, @radius : Int32)
      end

      # Bounds mirrors upstream's image.Rectangle for the rounded rect.
      def bounds : Tuple(Int32, Int32, Int32, Int32)
        {pa[0], pa[1], pb[0], pb[1]}
      end

      def alpha_at(x : Int32, y : Int32) : UInt8
        if corner = corner_circle(x, y)
          corner.alpha_at(x, y)
        else
          WHITE
        end
      end

      # The corner circles get one extra pixel of radius so that fully opaque
      # pixels line up with the rectangle: a circle's outermost pixels are
      # always antialiased and therefore transparent.
      private def corner_circle(x : Int32, y : Int32) : Circle?
        cx = corner_axis(x, pa[0], pb[0])
        cy = corner_axis(y, pa[1], pb[1])
        return nil unless cx && cy

        Circle.new({cx, cy}, radius + 1)
      end

      # Returns the corner circle's center along one axis when the coordinate
      # falls inside a corner band, nil otherwise.
      private def corner_axis(value : Int32, low : Int32, high : Int32) : Int32?
        return low + radius if value >= low && value < low + radius
        return high - radius if value >= high - radius && value < high

        nil
      end
    end

    # MakeBorderRadiusMask draws a mask that rounds a terminal's corners.
    def make_border_radius_mask(width : Int32, height : Int32, radius : Int32, target_png : String) : Exception?
      img = CrImage::Gray.new(CrImage.rect(0, 0, width, height))

      # Fill image with black, then put the rounded rectangle in white on top.
      fill_gray(img, 0_u8, Rectangle.new({0, 0}, {width, height}))
      blend_gray(img, WHITE, RoundedRectangle.new({0, 0}, {width, height}, radius))

      write_png(img, target_png)
    end

    # MakeWindowBar draws a window bar and saves it to a file.
    def make_window_bar(term_width : Int32, term_height : Int32, opts : StyleOptions, file : String) : Exception?
      case opts.window_bar
      when "Colorful"
        make_colorful_bar(term_width, term_height, false, opts, file)
      when "ColorfulRight"
        make_colorful_bar(term_width, term_height, true, opts, file)
      when "Rings"
        make_ring_bar(term_width, term_height, false, opts, file)
      when "RingsRight"
        make_ring_bar(term_width, term_height, true, opts, file)
      end
    end

    # Draws the macOS-style three-dot bar.
    def make_colorful_bar(term_width : Int32, term_height : Int32, is_right : Bool, opts : StyleOptions, target_png : String) : Exception?
      # Radius of dots
      dot_rad = opts.window_bar_size // BAR_TO_DOT_RATIO
      dot_dia = double(dot_rad)
      # Space between dots and edge
      dot_gap = half(opts.window_bar_size - dot_dia)
      # Space between dot centers
      dot_space = dot_dia + opts.window_bar_size // BAR_TO_DOT_RATIO

      width = term_width
      height = term_height + opts.window_bar_size

      img = CrImage.rgba(width, height)
      background, _ = parse_hex_color(opts.window_bar_color)

      # Full-image background, then the three dots over it.
      fill_rgba(img, background, Rectangle.new({0, 0}, {width, height}))

      dot_y = dot_rad + dot_gap
      if is_right
        draw_dot(img, COLORFUL_DOT_A, term_width - (dot_gap + dot_rad), dot_y, dot_rad, background)
        draw_dot(img, COLORFUL_DOT_B, term_width - (dot_gap + dot_rad + dot_space), dot_y, dot_rad, background)
        draw_dot(img, COLORFUL_DOT_C, term_width - (dot_gap + dot_rad + double(dot_space)), dot_y, dot_rad, background)
      else
        draw_dot(img, COLORFUL_DOT_A, dot_gap + dot_rad, dot_y, dot_rad, background)
        draw_dot(img, COLORFUL_DOT_B, dot_gap + dot_rad + dot_space, dot_y, dot_rad, background)
        draw_dot(img, COLORFUL_DOT_C, dot_gap + dot_rad + double(dot_space), dot_y, dot_rad, background)
      end

      write_png(img, target_png)
    end

    # Draws the outlined-ring bar.
    def make_ring_bar(term_width : Int32, term_height : Int32, is_right : Bool, opts : StyleOptions, target_png : String) : Exception?
      # Radius of rings
      outer_rad = opts.window_bar_size // BAR_TO_DOT_BORDER_RATIO
      outer_dia = double(outer_rad)
      inner_rad = double(outer_dia) // BAR_TO_DOT_BORDER_RATIO
      # Space between rings and edge
      ring_gap = half(opts.window_bar_size - outer_dia)
      # Space between ring centers
      ring_space = outer_dia + opts.window_bar_size // BAR_TO_DOT_RATIO

      width = term_width
      height = term_height + opts.window_bar_size

      img = CrImage.rgba(width, height)
      background, _ = parse_hex_color(opts.window_bar_color)

      fill_rgba(img, background, Rectangle.new({0, 0}, {width, height}))

      ring_y = outer_rad + ring_gap
      (0..2).each do |i|
        ring_x = if is_right
                   term_width - (ring_gap + outer_rad + i * ring_space)
                 else
                   ring_gap + outer_rad + i * ring_space
                 end

        draw_dot(img, RING_COLOR, ring_x, ring_y, outer_rad, background)
        draw_dot(img, background, ring_x, ring_y, inner_rad, RING_COLOR)
      end

      write_png(img, target_png)
    end

    # Parses a hex color the way upstream does: "#rrggbb", "rrggbb", "#rgb",
    # and "rgb" are accepted; anything else returns an error and the fallback
    # color (0x17, 0x17, 0x17, opaque).
    def parse_hex_color(s : String) : {CrImage::Color::RGBA, String?}
      color = CrImage::Color::RGBA.new(BLACK, BLACK, BLACK, WHITE)

      case s.size
      when 7
        rgb = parse_rgb(s, 1)
        return {color, "#{s} color of invalid length"} unless rgb
        color = CrImage::Color::RGBA.new(rgb[0], rgb[1], rgb[2], WHITE)
      when 6
        rgb = parse_rgb(s, 0)
        return {color, "#{s} color of invalid length"} unless rgb
        color = CrImage::Color::RGBA.new(rgb[0], rgb[1], rgb[2], WHITE)
      when 4
        nibbles = parse_nibbles(s, 1)
        return {color, "#{s} color of invalid length"} unless nibbles
        color = CrImage::Color::RGBA.new(nibbles[0] * 17, nibbles[1] * 17, nibbles[2] * 17, WHITE)
      when 3
        nibbles = parse_nibbles(s, 0)
        return {color, "#{s} color of invalid length"} unless nibbles
        color = CrImage::Color::RGBA.new(nibbles[0] * 17, nibbles[1] * 17, nibbles[2] * 17, WHITE)
      else
        return {color, "#{s} color of invalid length"}
      end

      {color, nil}
    end

    private def parse_rgb(s : String, offset : Int32) : Tuple(Int32, Int32, Int32)?
      return nil if s.size < offset + 6

      r = s[offset, 2].to_i?(16)
      g = s[offset + 2, 2].to_i?(16)
      b = s[offset + 4, 2].to_i?(16)
      return nil unless r && g && b

      {r, g, b}
    end

    private def parse_nibbles(s : String, offset : Int32) : Tuple(Int32, Int32, Int32)?
      return nil if s.size < offset + 3

      r = s[offset, 1].to_i?(16)
      g = s[offset + 1, 1].to_i?(16)
      b = s[offset + 2, 1].to_i?(16)
      return nil unless r && g && b

      {r, g, b}
    end

    private def fill_rgba(img : CrImage::RGBA, color : CrImage::Color::RGBA, mask : Rectangle) : Nil
      mask.pa[1].upto(mask.pb[1] - 1) do |y|
        mask.pa[0].upto(mask.pb[0] - 1) do |x|
          next unless mask.alpha_at(x, y) == WHITE
          img[x, y] = color
        end
      end
    end

    # Draws one antialiased dot over an opaque background.
    private def draw_dot(img : CrImage::RGBA, color : CrImage::Color::RGBA, cx : Int32, cy : Int32, radius : Int32, base : CrImage::Color::RGBA) : Nil
      circle = Circle.new({cx, cy}, radius)
      (cy - radius).upto(cy + radius) do |y|
        (cx - radius).upto(cx + radius) do |x|
          alpha = circle.alpha_at(x, y)
          next if alpha == 0

          img[x, y] = if alpha == WHITE
                        color
                      else
                        blend(color, base, alpha)
                      end
        end
      end
    end

    private def fill_gray(img : CrImage::Gray, value : UInt8, mask : Rectangle) : Nil
      mask.pa[1].upto(mask.pb[1] - 1) do |y|
        mask.pa[0].upto(mask.pb[0] - 1) do |x|
          next unless mask.alpha_at(x, y) == WHITE
          img.set_gray(x, y, CrImage::Color::Gray.new(value))
        end
      end
    end

    # Composites white over a black mask: the coverage value *is* the gray value,
    # which is what ffmpeg's alphamerge reads.
    private def blend_gray(img : CrImage::Gray, value : UInt8, mask : RoundedRectangle) : Nil
      mask.pa[1].upto(mask.pb[1] - 1) do |y|
        mask.pa[0].upto(mask.pb[0] - 1) do |x|
          alpha = mask.alpha_at(x, y)
          img.set_gray(x, y, CrImage::Color::Gray.new(blend_channel(value, 0_u8, alpha)))
        end
      end
    end

    private def blend(src : CrImage::Color::RGBA, base : CrImage::Color::RGBA, alpha : UInt8) : CrImage::Color::RGBA
      CrImage::Color::RGBA.new(
        blend_channel(src.r, base.r, alpha),
        blend_channel(src.g, base.g, alpha),
        blend_channel(src.b, base.b, alpha),
        WHITE
      )
    end

    # Straight-alpha source-over for two opaque colors.
    private def blend_channel(src : UInt8, base : UInt8, alpha : UInt8) : UInt8
      a = alpha.to_f64 / WHITE.to_f64
      (src.to_f64 * a + base.to_f64 * (1 - a)).round.to_u8
    end

    private def write_png(img : CrImage::Image, target_png : String) : Exception?
      dir = File.dirname(target_png)
      Dir.mkdir_p(dir) unless Dir.exists?(dir)
      CrImage::PNG.write(target_png, img)
      nil
    rescue ex
      ex
    end
  end
end
