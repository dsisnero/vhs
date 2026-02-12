require "../spec_helper"

module Vhs
  describe "evaluator simple" do
    it "executes simple tape without errors" do
      tape = <<-TAPE
      Output test.gif
      Sleep 0.1s
      TAPE

      errors = Vhs.evaluate(tape)
      puts "Errors: #{errors.inspect}"
      errors.should be_empty
    end
  end
end
