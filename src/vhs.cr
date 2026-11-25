# VHS is a Crystal port of the charmbracelet/vhs Go library for writing terminal GIFs as code.
#
# See the README for usage examples and documentation.
module Vhs
  VERSION = "0.1.0"
end

require "./vhs/*"
require "option_parser"

# CLI entry point
#
# Mirrors upstream main.go's cobra commands: running a tape file by default,
# plus the `record` and `publish` subcommands. The subcommands are dispatched on
# the first argument instead of through cobra.
module Vhs::CLI
  extend self

  # TapeArgs is the root command's parsed flag state.
  struct TapeArgs
    getter input : String
    getter? quiet : Bool
    getter? publish : Bool
    getter outputs : Array(String)

    def initialize(@input : String, @quiet : Bool, @publish : Bool, @outputs : Array(String))
    end
  end

  # OutputOverride is upstream's EvaluatorOption in main.go: it applies the -o
  # paths to the configured outputs and remembers which GIF to publish.
  class OutputOverride
    getter publish_file : String

    def initialize(@outputs : Array(String))
      @publish_file = ""
    end

    def option : Vhs::EvaluatorOption
      ->(v : Vhs::VHS) do
        apply(v)
        nil
      end
    end

    def apply(v : Vhs::VHS) : Nil
      if @outputs.empty?
        @publish_file = v.options.video.output.gif
        return
      end

      @outputs.each do |output|
        case
        when output.ends_with?(".gif")
          v.options.video.output.gif = output
        when output.ends_with?(".webm")
          v.options.video.output.webm = output
        when output.ends_with?(".mp4")
          v.options.video.output.mp4 = output
        end
      end

      @publish_file = v.options.video.output.gif
    end
  end

  def run(args = ARGV)
    # Match lipgloss' terminal negotiation (NO_COLOR, COLORTERM, TERM) so the
    # echo and error output carry the colour depth the terminal can show.
    Styles.configure

    case args.first?
    when "record"
      record_command(args[1..])
    when "publish"
      publish_command(args[1..])
    else
      evaluate(args)
    end
  end

  # evaluate runs a tape file, upstream's root command.
  private def evaluate(args : Array(String)) : NoReturn
    tape = parse_tape_args(args)

    if tape.input.empty?
      STDERR.puts "Error: no input provided"
      exit 1
    end

    override = OutputOverride.new(tape.outputs)
    STDERR.puts "Evaluating tape (#{tape.input.size} bytes)..." unless tape.quiet?
    errors = Vhs.evaluate(tape.input, tape.quiet? ? IO::Memory.new : STDOUT, override.option)

    show_publish_hint(tape) if errors.empty?

    unless errors.empty?
      Vhs.print_errors(STDERR, tape.input, errors)
      exit 1
    end

    publish_output(override.publish_file, tape.quiet?) if publish_requested?(tape.publish?)
    exit 0
  end

  private def parse_tape_args(args : Array(String)) : TapeArgs
    input = ""
    quiet = false
    publish = false
    outputs = [] of String

    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: vhs [options] [file]"
      parser.on("-o FILE", "--output=FILE", "Output file path(s)") do |file|
        outputs << file
      end
      parser.on("-q", "--quiet", "Quiet mode (suppress logs)") do
        quiet = true
      end
      parser.on("-p", "--publish", "Publish GIF to vhs.charm.sh") do
        publish = true
      end
      parser.on("-v", "--version", "Show version") do
        puts "vhs #{Vhs::VERSION}"
        exit 0
      end
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit 0
      end
      parser.unknown_args do |unknown|
        input = read_tape_input(unknown, parser, quiet)
      end
    end

    TapeArgs.new(input, quiet, publish, outputs)
  end

  # read_tape_input reads the tape from the file argument or from stdin.
  private def read_tape_input(unknown : Array(String), parser : OptionParser, quiet : Bool) : String
    return read_stdin_tape(parser) if unknown.empty?

    input_file = unknown[0]
    return STDIN.gets_to_end if input_file == "-"

    begin
      input = File.read(input_file)
    rescue ex
      STDERR.puts "Error reading file: #{ex.message}"
      exit 1
    end

    STDERR.puts Styles::GRAY_STYLE.render("File: #{input_file}") unless quiet
    input
  end

  private def read_stdin_tape(parser : OptionParser) : String
    # The user ran vhs without any arguments or stdin: print the usage.
    if STDIN.tty?
      puts parser
      exit 1
    end

    STDIN.gets_to_end
  end

  # show_publish_hint prints the hint upstream logs when nothing is published.
  private def show_publish_hint(tape : TapeArgs) : Nil
    return if publish_requested?(tape.publish?)
    return if ENV["VHS_PUBLISH"]?

    STDERR.puts Styles::FAINT_STYLE.render("Host your GIF on vhs.charm.sh: vhs publish <file>.gif")
  end

  # show_publishing prints upstream's "Publishing <file>..." line when stdout is
  # a terminal.
  private def show_publishing(file : String) : Nil
    return unless STDOUT.tty?

    STDERR.print Styles::GRAY_STYLE.render("Publishing #{file}... ")
  end

  private def publish_requested?(publish : Bool) : Bool
    publish || ENV["VHS_PUBLISH"]? == "true"
  end

  # publish_output uploads the rendered GIF, upstream's publish block.
  private def publish_output(file : String, quiet : Bool) : Nil
    return if file.empty?

    show_publishing(file) unless quiet

    begin
      url = Vhs.publish(file)
    rescue ex
      STDERR.puts ex.message
      exit 1
    end

    if quiet
      puts url
      return
    end

    if STDOUT.tty?
      STDERR.puts Styles::STRING_STYLE.render("Done!")
      Vhs.publish_share_instructions(url)
    end

    STDERR.puts "  " + Styles::URL_STYLE.render(url)
    STDERR.puts if STDOUT.tty?
  end

  # record_command writes a tape from an interactive session, upstream's
  # `record` command.
  private def record_command(args : Array(String)) : NoReturn
    shell = Vhs.default_record_shell

    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: vhs record [options]"
      parser.on("-s SHELL", "--shell=SHELL", "Shell for recording") do |value|
        shell = value
      end
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit 0
      end
    end

    begin
      Vhs.record(shell)
    rescue ex
      STDERR.puts ex.message
      exit 1
    end

    exit 0
  end

  # publish_command uploads a GIF, upstream's `publish` command.
  private def publish_command(args : Array(String)) : NoReturn
    quiet = false
    file = ""

    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: vhs publish <gif>"
      parser.on("-q", "--quiet", "Quiet mode (print the URL only)") do
        quiet = true
      end
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit 0
      end
      parser.unknown_args do |unknown|
        file = unknown[0] if unknown.size > 0
      end
    end

    if file.ends_with?(".tape")
      STDERR.puts "Use vhs #{file} --publish flag to publish tapes"
    end

    unless file.ends_with?(".gif")
      STDERR.puts "must pass a GIF file"
      exit 1
    end

    begin
      url = Vhs.publish(file)
    rescue ex
      STDERR.puts ex.message
      exit 1
    end

    if quiet || !STDOUT.tty?
      puts url
      exit 0
    end

    Vhs.publish_share_instructions(url)
    print "  " + Styles::URL_STYLE.render(url)
    puts
    exit 0
  end
end

# Run CLI if this file is executed directly
if PROGRAM_NAME == __FILE__ || File.basename(PROGRAM_NAME).includes?("vhs")
  Vhs::CLI.run
end
