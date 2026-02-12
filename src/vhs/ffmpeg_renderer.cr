require "process"
require "file_utils"

module Vhs
  # FFmpegRenderer handles converting PNG frames to video formats (GIF/WebM/MP4)
  # using FFmpeg command-line tool.
  module FFmpegRenderer
    extend self

    # Render video from frames using FFmpeg.
    # @param video_options [VideoOptions] video configuration
    # @param screenshot_options [ScreenshotOptions] screenshot configuration
    # @return [Exception?] error if any
    def render(video_options : VideoOptions, screenshot_options : ScreenshotOptions) : Exception?
      # Check if FFmpeg is available
      unless ffmpeg_available?
        return Exception.new("ffmpeg is not installed. Install it from: http://ffmpeg.org")
      end

      # Ensure output directories exist
      ensure_output_dirs(video_options, screenshot_options)

      # Build and execute FFmpeg commands
      cmds = [] of Process

      # Add video format commands
      if !video_options.output.gif.empty?
        cmd = build_gif_command(video_options)
        cmds << cmd if cmd
      end

      if !video_options.output.webm.empty?
        cmd = build_webm_command(video_options)
        cmds << cmd if cmd
      end

      if !video_options.output.mp4.empty?
        cmd = build_mp4_command(video_options)
        cmds << cmd if cmd
      end

      # Add screenshot commands
      screenshot_commands = build_screenshot_commands(screenshot_options)
      cmds.concat(screenshot_commands)

      # Execute commands
      cmds.each do |process_cmd|
        output = IO::Memory.new
        error = IO::Memory.new
        status = process_cmd.wait

        unless status.success?
          error_msg = "FFmpeg command failed: #{process_cmd.command.join(" ")}\n"
          error_msg += "Output: #{output}\n" unless output.empty?
          error_msg += "Error: #{error}" unless error.empty?
          return Exception.new(error_msg)
        end
      end

      nil
    end

    # Check if FFmpeg is available in PATH
    private def ffmpeg_available? : Bool
      Process.run("which", {"ffmpeg"}, output: Process::Redirect::Close, error: Process::Redirect::Close).success?
    end

    # Ensure output directories exist
    private def ensure_output_dirs(video_options : VideoOptions, screenshot_options : ScreenshotOptions) : Nil
      # Video outputs
      [video_options.output.gif, video_options.output.webm, video_options.output.mp4].each do |path|
        next if path.empty?
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
      end

      # Screenshot outputs
      screenshot_options.screenshots.keys.each do |path|
        next if path.empty?
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
      end
    end

    # Build FFmpeg command for GIF output
    private def build_gif_command(video_options : VideoOptions) : Process?
      return nil if video_options.output.gif.empty?

      args = build_common_args(video_options)

      # GIF-specific options
      args.concat([
        "-filter_complex", build_gif_filter_complex(video_options),
        video_options.output.gif,
      ])

      Process.new("ffmpeg", args, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
    end

    # Build FFmpeg command for WebM output
    private def build_webm_command(video_options : VideoOptions) : Process?
      return nil if video_options.output.webm.empty?

      args = build_common_args(video_options)

      # WebM-specific options
      args.concat([
        "-pix_fmt", "yuv420p",
        "-an",
        "-crf", "30",
        "-b:v", "0",
        video_options.output.webm,
      ])

      Process.new("ffmpeg", args, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
    end

    # Build FFmpeg command for MP4 output
    private def build_mp4_command(video_options : VideoOptions) : Process?
      return nil if video_options.output.mp4.empty?

      args = build_common_args(video_options)

      # MP4-specific options
      args.concat([
        "-vcodec", "libx264",
        "-pix_fmt", "yuv420p",
        "-an",
        "-crf", "20",
        video_options.output.mp4,
      ])

      Process.new("ffmpeg", args, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
    end

    # Build common FFmpeg arguments for all formats
    private def build_common_args(video_options : VideoOptions) : Array(String)
      args = [] of String

      # Overwrite output files
      args << "-y"

      # Input frame rate
      args.concat(["-r", video_options.framerate.to_s])

      # Starting frame number
      args.concat(["-start_number", video_options.starting_frame.to_s])

      # Input frames pattern
      # Note: We only have text frames (no cursor frames in current implementation)
      frame_pattern = File.join(video_options.input, "frame_%04d.png")
      args.concat(["-i", frame_pattern])

      args
    end

    # Build filter complex for GIF (palette generation)
    private def build_gif_filter_complex(video_options : VideoOptions) : String
      # Simple palette generation for GIF
      # [0] is our input frames
      "split [a][b]; [a] palettegen [p]; [b][p] paletteuse"
    end

    # Build screenshot commands
    private def build_screenshot_commands(screenshot_options : ScreenshotOptions) : Array(Process)
      cmds = [] of Process

      screenshot_options.screenshots.each do |path, frame_num|
        # For now, use a simple approach: copy the specific frame
        # TODO: Implement proper screenshot styling with margins, bars, etc.
        input_frame = File.join(screenshot_options.input, sprintf("frame_%04d.png", frame_num))

        if File.exists?(input_frame)
          args = [
            "-y",
            "-i", input_frame,
            path,
          ]

          cmds << Process.new("ffmpeg", args, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
        end
      end

      cmds
    end
  end
end
