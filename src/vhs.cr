# VHS is a Crystal port of the charmbracelet/vhs Go library for writing terminal GIFs as code.
#
# See the README for usage examples and documentation.
module Vhs
  VERSION = "0.1.0"

  # TODO: Put your code here
end

require "./vhs/*"
require "option_parser"

# CLI entry point
module Vhs::CLI
  extend self

  def run(args = ARGV)
    STDERR.puts "DEBUG: CLI run with args #{args}"
    STDERR.flush
    input = ""
    input_file = ""
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
        STDERR.puts "DEBUG: version flag triggered"
        puts "vhs #{Vhs::VERSION}"
        exit 0
      end
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit 0
      end
      parser.unknown_args do |args|
        STDERR.puts "DEBUG: unknown_args called with #{args}"
        if args.size > 0
          input_file = args[0]
          STDERR.puts "DEBUG: input_file #{input_file}"
          if input_file == "-"
            # Read from stdin
            input = STDIN.gets_to_end
          else
            # Read from file
            begin
              input = File.read(input_file)
            rescue ex
              STDERR.puts "Error reading file: #{ex.message}"
              exit 1
            end
          end
        else
          # No file argument, check if stdin has data
          if STDIN.tty?
            puts parser
            exit 1
          else
            input = STDIN.gets_to_end
          end
        end
      end
    end

    STDERR.puts "DEBUG: Input size #{input.size}"
    if input.empty?
      STDERR.puts "Error: no input provided"
      exit 1
    end

    # Override output paths if specified
    # TODO: Implement output path overriding

    # Run evaluation
    STDERR.puts "Evaluating tape (#{input.size} bytes)..." unless quiet
    errors = Vhs.evaluate(input, quiet ? IO::Memory.new : STDOUT)

    unless errors.empty?
      errors.each do |err|
        STDERR.puts "Error: #{err.message}"
      end
      exit 1
    end

    # TODO: Implement publish
    if publish
      STDERR.puts "Publishing not yet implemented"
    end

    exit 0
  end
end

# Run CLI if this file is executed directly
if PROGRAM_NAME == __FILE__ || File.basename(PROGRAM_NAME).includes?("vhs")
  Vhs::CLI.run
end
