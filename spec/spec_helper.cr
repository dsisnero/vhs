require "spec"
require "../src/vhs"

# Evaluates a tape without rendering, so specs never spawn ffmpeg or write
# video files into the working directory. Clears the configured outputs through
# the EvaluatorOption hook, which runs just before upstream's Render step.
def evaluate_without_render(tape : String, output : IO = STDOUT) : Array(Exception)
  drop_outputs = ->(v : Vhs::VHS) do
    v.options.video.output = Vhs::VideoOutputs.new
    v.options.screenshot.screenshots.clear
    nil
  end
  Vhs.evaluate(tape, output, drop_outputs)
end
