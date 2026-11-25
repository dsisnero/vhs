require "process"

module Vhs
  # Frame file names, matching upstream video.go's textFrameFormat and
  # cursorFrameFormat. The renderer feeds both streams to ffmpeg and overlays
  # them, exactly like xterm.js' text and cursor canvases.
  TEXT_FRAME_FORMAT   = "frame-text-%05d.png"
  CURSOR_FRAME_FORMAT = "frame-cursor-%05d.png"

  GIF_EXT  = ".gif"
  WEBM_EXT = ".webm"
  MP4_EXT  = ".mp4"

  # margin_fill_is_color returns whether the margin fill is a color (rather than
  # a path to an image).
  def self.margin_fill_is_color?(margin_fill : String) : Bool
    margin_fill.starts_with?('#')
  end

  # calc_term_dimensions computes the terminal (frame) dimensions after the
  # margin and window bar are accounted for.
  def self.calc_term_dimensions(style : StyleOptions) : {Int32, Int32}
    width = style.width
    height = style.height
    if !style.margin_fill.empty?
      width -= double(style.margin)
      height -= double(style.margin)
    end
    if !style.window_bar.empty?
      height -= style.window_bar_size
    end

    {width, height}
  end

  # Generates the -filter_complex value of an ffmpeg invocation.
  class FilterComplexBuilder
    # Filter preamble shared by the video and screenshot pipelines. `%s` slots
    # are filled in order; the leading newline and tabs match upstream's raw
    # string literals.
    VIDEO_FILTER_HEAD = "\n\t\t[0][1]overlay[merged];" \
                        "\n\t\t[merged]scale=%d:%d:force_original_aspect_ratio=1[scaled];" \
                        "\n\t\t[scaled]fps=%d,setpts=PTS/%f[speed];" \
                        "\n\t\t[speed]pad=%d:%d:(ow-iw)/2:(oh-ih)/2:%s[padded];" \
                        "\n\t\t[padded]fillborders=left=%d:right=%d:top=%d:bottom=%d:mode=fixed:color=%s[padded]" \
                        "\n\t\t"

    SCREENSHOT_FILTER_HEAD = "\n\t\t[0][1]overlay[merged];" \
                             "\n\t\t[merged]scale=%d:%d:force_original_aspect_ratio=1[scaled];" \
                             "\n\t\t[scaled]pad=%d:%d:(ow-iw)/2:(oh-ih)/2:%s[padded];" \
                             "\n\t\t[padded]fillborders=left=%d:right=%d:top=%d:bottom=%d:mode=fixed:color=%s[padded]" \
                             "\n\t\t"

    WINDOW_BAR_STAGE = "\n\t\t\t[%d]loop=-1[loopbar];" \
                       "\n\t\t\t[loopbar][%s]overlay=0:%d[withbar]" \
                       "\n\t\t\t"

    BORDER_RADIUS_STAGE = "\n\t\t\t[%d]loop=-1[loopmask];" \
                          "\n\t\t\t[%s][loopmask]alphamerge[rounded]" \
                          "\n\t\t\t"

    MARGIN_FILL_STAGE = "\n\t\t\t[%d]scale=%d:%d[bg];" \
                        "\n\t\t\t[bg][%s]overlay=(W-w)/2:(H-h)/2:shortest=1[withbg]" \
                        "\n\t\t\t"

    GIF_STAGE = "\n\t\t[%s]split[plt_a][plt_b];" \
                "\n\t\t[plt_a]palettegen=max_colors=256[plt];" \
                "\n\t\t[plt_b][plt]paletteuse[palette]"

    getter style : StyleOptions
    getter term_width : Int32
    getter term_height : Int32
    getter prev_stage_name : String
    # IO::Memory (rather than String::Builder) because build is a pure read that
    # specs and callers may repeat.
    getter filter_complex : IO::Memory

    def initialize(@filter_complex : IO::Memory, @style : StyleOptions, @term_width : Int32,
                   @term_height : Int32, @prev_stage_name : String)
    end

    # Creates a builder for video rendering.
    def self.new_video(video_options : VideoOptions) : FilterComplexBuilder
      style = video_options.style
      term_width, term_height = Vhs.calc_term_dimensions(style)
      filter = IO::Memory.new

      filter << sprintf(
        VIDEO_FILTER_HEAD,
        term_width - style.padding * 2,
        term_height - style.padding * 2,
        video_options.framerate,
        video_options.playback_speed,
        term_width,
        term_height,
        style.background_color,
        style.padding,
        style.padding,
        style.padding,
        style.padding,
        style.background_color
      )

      new(filter, style, term_width, term_height, "padded")
    end

    # Creates a builder for screenshot rendering.
    def self.new_screenshot(style : StyleOptions) : FilterComplexBuilder
      term_width, term_height = Vhs.calc_term_dimensions(style)
      filter = IO::Memory.new

      filter << sprintf(
        SCREENSHOT_FILTER_HEAD,
        term_width - style.padding * 2,
        term_height - style.padding * 2,
        term_width,
        term_height,
        style.background_color,
        style.padding,
        style.padding,
        style.padding,
        style.padding,
        style.background_color
      )

      new(filter, style, term_width, term_height, "padded")
    end

    # WithWindowBar adds the window bar options to the filter complex.
    def with_window_bar(bar_stream : Int32) : self
      return self if style.window_bar.empty?

      filter_complex << ";"
      filter_complex << sprintf(WINDOW_BAR_STAGE, bar_stream, prev_stage_name, style.window_bar_size)
      @prev_stage_name = "withbar"
      self
    end

    # WithBorderRadius adds the border radius options to the filter complex.
    def with_border_radius(corner_mark_stream : Int32) : self
      return self if style.border_radius == 0

      filter_complex << ";"
      filter_complex << sprintf(BORDER_RADIUS_STAGE, corner_mark_stream, prev_stage_name)
      @prev_stage_name = "rounded"
      self
    end

    # WithMarginFill adds the margin options to the filter complex.
    def with_margin_fill(margin_stream : Int32) : self
      return self if style.margin_fill.empty?

      # ffmpeg complains when the final filter ends with a semicolon, so the
      # separator is written before the stage.
      filter_complex << ";"
      filter_complex << sprintf(MARGIN_FILL_STAGE, margin_stream, style.width, style.height, prev_stage_name)
      @prev_stage_name = "withbg"
      self
    end

    # WithGIF adds the palette stages used for GIF output.
    def with_gif : self
      filter_complex << ";"
      filter_complex << sprintf(GIF_STAGE, prev_stage_name)
      @prev_stage_name = "palette"
      self
    end

    # Build returns the -filter_complex / -map arguments.
    def build : Array(String)
      ["-filter_complex", filter_complex.to_s, "-map", "[#{prev_stage_name}]"]
    end
  end

  # Generates the input streams used by an ffmpeg invocation.
  class StreamBuilder
    getter args : Array(String)
    getter counter : Int32
    getter style : StyleOptions
    getter term_width : Int32
    getter term_height : Int32
    getter input : String
    getter bar_stream : Int32
    getter corner_stream : Int32
    getter margin_stream : Int32

    def initialize(@counter : Int32, @input : String, @style : StyleOptions)
      @args = [] of String
      term_width, term_height = Vhs.calc_term_dimensions(style)
      @term_width = term_width
      @term_height = term_height
      @bar_stream = 0
      @corner_stream = 0
      @margin_stream = 0
    end

    # WithMargin adds the margin stream: a flat color, or a looping image.
    def with_margin : self
      return self if style.margin_fill.empty?

      if Vhs.margin_fill_is_color?(style.margin_fill)
        args.concat([
          "-f", "lavfi",
          "-i", "color=#{style.margin_fill}:s=#{style.width}x#{style.height}",
        ])
      else
        unless File.exists?(style.margin_fill)
          STDERR.puts "#{Styles::ERROR_STYLE.render("Unable to read margin file: ")}#{style.margin_fill}"
        end

        args.concat(["-loop", "1", "-i", style.margin_fill])
      end

      @margin_stream = counter
      @counter += 1
      self
    end

    # WithBar adds the window bar stream, drawing the bar image first.
    def with_bar : self
      bar_path = File.join(input, "bar.png")

      unless style.window_bar.empty?
        Vhs::Draw.make_window_bar(term_width, term_height, style, bar_path)
        args.concat(["-i", bar_path])
        @bar_stream = counter
        @counter += 1
      end

      self
    end

    # WithCorner adds the border radius mask stream.
    def with_corner : self
      mask_path = File.join(input, "mask.png")

      unless style.border_radius == 0
        if style.window_bar.empty?
          Vhs::Draw.make_border_radius_mask(term_width, term_height, style.border_radius, mask_path)
        else
          Vhs::Draw.make_border_radius_mask(term_width, term_height + style.window_bar_size, style.border_radius, mask_path)
        end

        args.concat(["-i", mask_path])
        @corner_stream = counter
        @counter += 1
      end

      self
    end

    # WithMP4 adds the mp4 encoding flags.
    def with_mp4 : self
      args.concat(["-vcodec", "libx264", "-pix_fmt", "yuv420p", "-an", "-crf", "20"])
      self
    end

    # WithWebm adds the webm encoding flags.
    def with_webm : self
      args.concat(["-pix_fmt", "yuv420p", "-an", "-crf", "30", "-b:v", "0"])
      self
    end

    # Build returns the stream arguments.
    def build : Array(String)
      args
    end
  end

  # build_ff_opts assembles an ffmpeg argument list from VideoOptions, mirroring
  # upstream video.go's buildFFopts.
  def self.build_ff_opts(opts : VideoOptions, target_file : String) : Array(String)
    args = [] of String
    stream_counter = 2

    stream_builder = StreamBuilder.new(stream_counter, opts.input, opts.style)

    # Stream 0: text frames, stream 1: cursor frames.
    stream_builder.args.concat([
      "-y",
      "-r", opts.framerate.to_s,
      "-start_number", opts.starting_frame.to_s,
      "-i", File.join(opts.input, TEXT_FRAME_FORMAT),
      "-r", opts.framerate.to_s,
      "-start_number", opts.starting_frame.to_s,
      "-i", File.join(opts.input, CURSOR_FRAME_FORMAT),
    ])

    stream_builder.with_margin.with_bar.with_corner

    filter_builder = FilterComplexBuilder.new_video(opts)
      .with_window_bar(stream_builder.bar_stream)
      .with_border_radius(stream_builder.corner_stream)
      .with_margin_fill(stream_builder.margin_stream)

    case File.extname(target_file)
    when GIF_EXT
      filter_builder = filter_builder.with_gif
    when WEBM_EXT
      stream_builder = stream_builder.with_webm
    when MP4_EXT
      stream_builder = stream_builder.with_mp4
    end

    args.concat(stream_builder.build)
    args.concat(filter_builder.build)
    args << target_file
    args
  end

  # build_screenshot_opts assembles the ffmpeg arguments for one deferred
  # screenshot, mirroring upstream ScreenshotOptions.buildFFopts: the text and
  # cursor frames for that single frame are the two inputs.
  def self.build_screenshot_opts(opts : ScreenshotOptions, target_file : String, frame : Int32) : Array(String)
    text_stream = File.join(opts.input, sprintf(TEXT_FRAME_FORMAT, frame))
    cursor_stream = File.join(opts.input, sprintf(CURSOR_FRAME_FORMAT, frame))

    stream_builder = StreamBuilder.new(2, opts.input, opts.style)
    stream_builder.args.concat(["-y", "-i", text_stream, "-i", cursor_stream])
    stream_builder.with_margin.with_bar.with_corner

    filter_builder = FilterComplexBuilder.new_screenshot(opts.style)
      .with_window_bar(stream_builder.bar_stream)
      .with_border_radius(stream_builder.corner_stream)
      .with_margin_fill(stream_builder.margin_stream)

    args = [] of String
    args.concat(stream_builder.build)
    args.concat(filter_builder.build)
    args << target_file
    args
  end

  # make_media returns the ffmpeg argument list for one output, or nil when the
  # output is not configured. Upstream returns an *exec.Cmd; the port returns the
  # arguments and lets the renderer spawn the process.
  def self.make_media(opts : VideoOptions, target_file : String) : Array(String)?
    return nil if target_file.empty?

    build_ff_opts(opts, target_file)
  end

  # MakeGIF converts the frames into a GIF.
  def self.make_gif(opts : VideoOptions) : Array(String)?
    make_media(opts, opts.output.gif)
  end

  # MakeMP4 converts the frames into an MP4.
  def self.make_mp4(opts : VideoOptions) : Array(String)?
    make_media(opts, opts.output.mp4)
  end

  # MakeWebM converts the frames into a WebM.
  def self.make_webm(opts : VideoOptions) : Array(String)?
    make_media(opts, opts.output.webm)
  end
end
