require "../spec_helper"

module Vhs
  describe "evaluator test" do
    it "returns error for invalid setting" do
      tape = <<-TAPE
      Set InvalidSetting 123
      TAPE

      errors = Vhs.evaluate(tape)
      puts "Errors size: #{errors.size}"
      errors.each_with_index do |err, i|
        puts "Error #{i}: #{err.class} - #{err.message}"
      end
      errors.should_not be_empty
    end

    it "returns no error for valid setting" do
      tape = <<-TAPE
      Output test.gif
      Set FontSize 16
      Sleep 0.1s
      TAPE

      errors = Vhs.evaluate(tape)
      puts "Errors: #{errors.size}"
      errors.should be_empty
    end
  end
end
