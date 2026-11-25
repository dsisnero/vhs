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

def evaluate_without_render(tape : String, output : IO = IO::Memory.new) : Array(Exception)
  Vhs.evaluate(tape, output, drop_outputs_option)
end

# Pin the colour profile so style output is byte-stable: the ANSI palette is what
# these terminals render, and it keeps the escape sequences in specs readable.
Lipgloss::StyleRenderer.default.color_profile = Lipgloss::ColorProfile::ANSI

# Browser-backed specs need ttyd and a Chromium-family browser, and each VHS
# launch costs seconds, so they only run when explicitly enabled:
#
#   VHS_SPEC_BROWSER=1 crystal spec
#
# The rest of the suite stays fast and dependency-free.
def browser_specs? : Bool
  case ENV["VHS_SPEC_BROWSER"]?
  when "1", "true", "yes"
    true
  else
    false
  end
end

# starts a VHS with a small video size and the given shell, ready for browser
# interactions. Callers must #stop it (or #close).
def browser_vhs(shell : Vhs::Shell = Vhs::Shell.new(command: ["bash", "--noprofile", "--norc"]), width : Int32 = 640, height : Int32 = 320) : Vhs::VHS
  options = Vhs.default_vhs_options
  options.shell = shell
  options.style.width = width
  options.style.height = height
  options.style.padding = 20
  options.style.background_color = Vhs::BACKGROUND
  options.video.framerate = 25

  vhs = Vhs::VHS.new
  vhs.options = options
  vhs.start.should be_nil
  vhs.setup.should be_nil
  vhs
end
