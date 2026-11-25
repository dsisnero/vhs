module Vhs
  # parse_duration parses a duration string the way Go's time.ParseDuration does,
  # which is what every tape-facing time value goes through upstream.
  #
  # Accepted: an optional sign, then one or more `<number><unit>` components,
  # where unit is ns, us, µs, μs, ms, s, m, or h and the number may be fractional
  # (`1.5h`, `2h45m`, `.5s`). "0" is valid and means zero. Returns nil otherwise.
  NANOSECOND            =             1_i64
  MICROSECOND           =         1_000_i64
  MILLISECOND           =     1_000_000_i64
  SECOND                = 1_000_000_000_i64
  MINUTE                = 60_i64 * SECOND
  HOUR                  = 60_i64 * MINUTE
  DURATION_UNITS_BY_LEN = {
    "ns" => NANOSECOND,
    "us" => MICROSECOND,
    "µs" => MICROSECOND,
    "μs" => MICROSECOND,
    "ms" => MILLISECOND,
    "s"  => SECOND,
    "m"  => MINUTE,
    "h"  => HOUR,
  }.to_a.sort_by { |(unit, _)| -unit.size }

  def self.parse_duration(text : String) : Time::Span?
    return 0.nanoseconds if text == "0"

    remaining = text
    negative = false
    if remaining.starts_with?('-')
      negative = true
      remaining = remaining[1..]
    elsif remaining.starts_with?('+')
      remaining = remaining[1..]
    end
    return nil if remaining.empty?

    total = 0_i64
    while !remaining.empty?
      value, remaining = split_number(remaining)
      return nil if value.nil?

      unit = DURATION_UNITS_BY_LEN.find { |(candidate, _)| remaining.starts_with?(candidate) }
      return nil if unit.nil?

      total += (value * unit[1]).to_i64
      remaining = remaining[unit[0].size..]
    end

    span = total.nanoseconds
    negative ? -span : span
  end

  # Splits a leading decimal number off the text, returning it with the rest.
  private def self.split_number(text : String) : {Float64?, String}
    integer_digits = digit_run(text, 0)
    length = integer_digits
    if length < text.size && text[length] == '.'
      length += 1 + digit_run(text, length + 1)
    end
    return {nil, text} if integer_digits == 0 && length == 0
    return {nil, text} if text[0, length] == "."

    value = text[0, length].to_f64?
    {value, text[length..]}
  end

  private def self.digit_run(text : String, from : Int32) : Int32
    count = 0
    while from + count < text.size && text[from + count].ascii_number?
      count += 1
    end
    count
  end
end
