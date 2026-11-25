require "../spec_helper"
require "file_utils"

private def draw_bar_options(window_bar : String) : Vhs::StyleOptions
  Vhs::StyleOptions.new(
    window_bar: window_bar,
    window_bar_size: 30,
    window_bar_color: "#171717"
  )
end

private def pixel_rgba(img : CrImage::Image, x : Int32, y : Int32) : Tuple(UInt8, UInt8, UInt8, UInt8)
  color = img.as(CrImage::RGBA)[x, y].as(CrImage::Color::RGBA)
  {color.r, color.g, color.b, color.a}
end

private def pixel_gray(img : CrImage::Image, x : Int32, y : Int32) : UInt8
  img.as(CrImage::Gray)[x, y].as(CrImage::Color::Gray).y
end

module Vhs
  # Characterization specs for the upstream draw.go port. Upstream has no Go
  # tests for these, so the assertions pin the generated pixels.
  describe Draw do
    describe ".parse_hex_color" do
      it "parses #rrggbb" do
        color, error = Draw.parse_hex_color("#171717")
        error.should be_nil
        color.should eq(CrImage::Color::RGBA.new(0x17, 0x17, 0x17, 0xFF))
      end

      it "parses rrggbb without the hash" do
        color, error = Draw.parse_hex_color("ff0000")
        error.should be_nil
        color.should eq(CrImage::Color::RGBA.new(0xFF, 0x00, 0x00, 0xFF))
      end

      it "expands #rgb nibbles" do
        color, error = Draw.parse_hex_color("#f0a")
        error.should be_nil
        color.should eq(CrImage::Color::RGBA.new(0xFF, 0x00, 0xAA, 0xFF))
      end

      it "expands rgb nibbles" do
        color, error = Draw.parse_hex_color("abc")
        error.should be_nil
        color.should eq(CrImage::Color::RGBA.new(0xAA, 0xBB, 0xCC, 0xFF))
      end

      it "falls back to the upstream default color on invalid length" do
        color, error = Draw.parse_hex_color("#ffff")
        error.should eq("#ffff color of invalid length")
        color.should eq(CrImage::Color::RGBA.new(0x17, 0x17, 0x17, 0xFF))
      end

      it "falls back on non-hex digits" do
        color, error = Draw.parse_hex_color("#zzzzzz")
        error.should_not be_nil
        color.should eq(CrImage::Color::RGBA.new(0x17, 0x17, 0x17, 0xFF))
      end
    end

    describe ".double and .half" do
      it "mirrors upstream's integer helpers" do
        Draw.double(7).should eq(14)
        Draw.half(7).should eq(3)
      end
    end

    describe "alpha masks" do
      it "reports circle bounds and antialiased coverage" do
        circle = Draw::Circle.new({10, 10}, 5)

        circle.bounds.should eq({5, 5, 15, 15})
        circle.alpha_at(10, 10).should eq(255)
        circle.alpha_at(100, 100).should eq(0)
        # The radius is shrunk by one pixel, so the rim is partially covered.
        rim = circle.alpha_at(14, 10)
        rim.should be > 0
        rim.should be < 255
      end

      it "reports rect bounds and coverage" do
        rect = Draw::Rectangle.new({2, 3}, {7, 9})

        rect.bounds.should eq({2, 3, 7, 9})
        rect.alpha_at(2, 3).should eq(255)
        rect.alpha_at(6, 8).should eq(255)
        rect.alpha_at(7, 8).should eq(0)
        rect.alpha_at(2, 9).should eq(0)
      end

      it "reports rounded rect bounds and rounded corner coverage" do
        rounded = Draw::RoundedRectangle.new({0, 0}, {100, 100}, 10)

        rounded.bounds.should eq({0, 0, 100, 100})
        rounded.alpha_at(50, 50).should eq(255)
        rounded.alpha_at(0, 0).should eq(0)
        rounded.alpha_at(50, 0).should eq(255)
        rounded.alpha_at(99, 50).should eq(255)
      end
    end

    describe ".make_border_radius_mask" do
      it "writes a grayscale mask with rounded corners" do
        path = "./temp/draw-mask.png"
        Draw.make_border_radius_mask(200, 100, 10, path).should be_nil

        img = CrImage::PNG.read(path)
        img.bounds.max.x.should eq(200)
        img.bounds.max.y.should eq(100)

        pixel_gray(img, 100, 50).should eq(255)
        pixel_gray(img, 0, 0).should eq(0)
        pixel_gray(img, 199, 0).should eq(0)
        pixel_gray(img, 0, 99).should eq(0)
        pixel_gray(img, 199, 99).should eq(0)
        # Middle of each edge stays fully opaque.
        pixel_gray(img, 100, 0).should eq(255)
        pixel_gray(img, 0, 50).should eq(255)
        File.delete(path)
      end
    end

    describe ".make_window_bar" do
      it "draws the colorful bar with three dots on the left" do
        path = "./temp/draw-bar.png"
        opts = draw_bar_options("Colorful")
        Draw.make_window_bar(200, 100, opts, path).should be_nil

        img = CrImage::PNG.read(path)
        # Bar height grows by the window bar size.
        img.bounds.max.y.should eq(130)
        img.bounds.max.x.should eq(200)

        pixel_rgba(img, 0, 0).should eq({0x17_u8, 0x17_u8, 0x17_u8, 0xFF_u8})
        pixel_rgba(img, 15, 15).should eq({0xFF_u8, 0x4F_u8, 0x4D_u8, 0xFF_u8})
        pixel_rgba(img, 30, 15).should eq({0xFE_u8, 0xBB_u8, 0x00_u8, 0xFF_u8})
        pixel_rgba(img, 45, 15).should eq({0x00_u8, 0xCC_u8, 0x1D_u8, 0xFF_u8})
        File.delete(path)
      end

      it "mirrors the dots for ColorfulRight" do
        path = "./temp/draw-bar-right.png"
        Draw.make_window_bar(200, 100, draw_bar_options("ColorfulRight"), path).should be_nil

        img = CrImage::PNG.read(path)
        pixel_rgba(img, 185, 15).should eq({0xFF_u8, 0x4F_u8, 0x4D_u8, 0xFF_u8})
        pixel_rgba(img, 170, 15).should eq({0xFE_u8, 0xBB_u8, 0x00_u8, 0xFF_u8})
        pixel_rgba(img, 155, 15).should eq({0x00_u8, 0xCC_u8, 0x1D_u8, 0xFF_u8})
        File.delete(path)
      end

      it "draws the ringed bar with hollow rings" do
        path = "./temp/draw-rings.png"
        Draw.make_window_bar(200, 100, draw_bar_options("Rings"), path).should be_nil

        img = CrImage::PNG.read(path)
        # Ring center is the background color, the ring body is 0x333333.
        pixel_rgba(img, 15, 15).should eq({0x17_u8, 0x17_u8, 0x17_u8, 0xFF_u8})
        # 4px from the center is inside the opaque ring body (the rim is antialiased).
        pixel_rgba(img, 19, 15).should eq({0x33_u8, 0x33_u8, 0x33_u8, 0xFF_u8})
        pixel_rgba(img, 32, 15).should eq({0x17_u8, 0x17_u8, 0x17_u8, 0xFF_u8})
        File.delete(path)
      end

      it "mirrors the rings for RingsRight" do
        path = "./temp/draw-rings-right.png"
        Draw.make_window_bar(200, 100, draw_bar_options("RingsRight"), path).should be_nil

        img = CrImage::PNG.read(path)
        pixel_rgba(img, 185, 15).should eq({0x17_u8, 0x17_u8, 0x17_u8, 0xFF_u8})
        pixel_rgba(img, 180, 15).should eq({0x33_u8, 0x33_u8, 0x33_u8, 0xFF_u8})
        File.delete(path)
      end

      it "does nothing for an unknown bar style" do
        path = "./temp/draw-bar-unknown.png"
        Draw.make_window_bar(200, 100, draw_bar_options("Nope"), path).should be_nil
        File.exists?(path).should be_false
      end
    end
  end
end
