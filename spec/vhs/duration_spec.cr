require "../spec_helper"

module Vhs
  # Characterization specs for Vhs.parse_duration, which stands in for Go's
  # time.ParseDuration: every tape-facing duration goes through it.
  describe ".parse_duration" do
    it "parses single units" do
      Vhs.parse_duration("1ns").should eq(1.nanoseconds)
      Vhs.parse_duration("300ms").should eq(300.milliseconds)
      Vhs.parse_duration("2s").should eq(2.seconds)
      Vhs.parse_duration("1m").should eq(1.minute)
      Vhs.parse_duration("1h").should eq(1.hour)
    end

    it "parses the microsecond spellings Go accepts" do
      Vhs.parse_duration("5us").should eq(5.microseconds)
      Vhs.parse_duration("5µs").should eq(5.microseconds)
      Vhs.parse_duration("5μs").should eq(5.microseconds)
    end

    it "parses fractions and multi-component durations" do
      Vhs.parse_duration("1.5h").should eq(90.minutes)
      Vhs.parse_duration(".5s").should eq(500.milliseconds)
      Vhs.parse_duration("2h45m").should eq(165.minutes)
      Vhs.parse_duration("1m30s").should eq(90.seconds)
    end

    it "parses signs and zero" do
      Vhs.parse_duration("0").should eq(0.nanoseconds)
      Vhs.parse_duration("+2s").should eq(2.seconds)
      Vhs.parse_duration("-1s").should eq(-1.second)
    end

    it "rejects what Go rejects" do
      Vhs.parse_duration("").should be_nil
      Vhs.parse_duration("1").should be_nil
      Vhs.parse_duration("s").should be_nil
      Vhs.parse_duration("1d").should be_nil
      Vhs.parse_duration("1.5").should be_nil
      Vhs.parse_duration("2x").should be_nil
    end
  end
end
