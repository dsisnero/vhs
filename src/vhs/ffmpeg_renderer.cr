require "process"
require "file_utils"

module Vhs
  # FFmpegRenderer runs ffmpeg over the captured frame streams, mirroring
  # upstream video.go's MakeGIF/MakeMP4/MakeWebM/MakeScreenshots and Render.
  module FFmpegRenderer
    extend self

    # Render converts the captured frames into every configured output and then
    # renders the deferred screenshots.
    #
    # Like upstream Render, a failing ffmpeg invocation is logged rather than
    # returned: the caller only sees setup failures.
    def render(video_options : VideoOptions, screenshot_options : ScreenshotOptions) : Exception?
      # Nothing to render: skip the ffmpeg probe entirely.
      return nil if no_outputs?(video_options, screenshot_options)

      unless ffmpeg_available?
        return Exception.new("ffmpeg is not installed. Install it from: http://ffmpeg.org")
      end

      commands = [] of Array(String)

      # Upstream Render appends MakeGIF, MakeMP4, MakeWebM, then the screenshots.
      {Vhs.make_gif(video_options), Vhs.make_mp4(video_options), Vhs.make_webm(video_options)}.each do |args|
        next if args.nil?

        ensure_dir(args.last)
        commands << args
      end

      commands.concat(screenshot_commands(screenshot_options))

      commands.each do |args|
        output = IO::Memory.new
        status = Process.run("ffmpeg", args, output: output, error: output)
        STDERR.puts output.to_s unless status.success?
      end

      nil
    end

    # Screenshot arguments for every frame captured by the Screenshot command.
    def screenshot_commands(screenshot_options : ScreenshotOptions) : Array(Array(String))
      screenshot_options.screenshots.map do |path, frame|
        Vhs.build_screenshot_opts(screenshot_options, path, frame)
      end
    end

    # no_outputs? is true when the tape configured no video output and no
    # deferred screenshots, in which case there is nothing to run.
    private def no_outputs?(video_options : VideoOptions, screenshot_options : ScreenshotOptions) : Bool
      video_options.output.gif.empty? &&
        video_options.output.mp4.empty? &&
        video_options.output.webm.empty? &&
        screenshot_options.screenshots.empty?
    end

    private def ffmpeg_available? : Bool
      Process.run("which", {"ffmpeg"}, output: Process::Redirect::Close, error: Process::Redirect::Close).success?
    rescue File::NotFoundError
      # `which` itself is missing from PATH.
      false
    end

    # ensure_dir creates the parent folders needed for an output path.
    private def ensure_dir(target : String) : Nil
      dir = File.dirname(target)
      return if dir.empty? || Dir.exists?(dir)

      FileUtils.mkdir_p(dir)
    end
  end
end
