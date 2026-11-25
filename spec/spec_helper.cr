require "spec"
require "../src/vhs"

# Evaluates a tape without rendering, so specs never spawn ffmpeg or write
# video files into the working directory. Clears the configured outputs through
# the EvaluatorOption hook, which runs just before upstream's Render step.
#
# Append `drop_outputs_option` after other options to keep a custom-option spec
# hermetic too.
def drop_outputs_option : Vhs::EvaluatorOption
  ->(v : Vhs::VHS) do
    v.options.video.output = Vhs::VideoOutputs.new
    v.options.screenshot.screenshots.clear
    nil
  end
end

def evaluate_without_render(tape : String, output : IO = STDOUT) : Array(Exception)
  Vhs.evaluate(tape, output, drop_outputs_option)
end
