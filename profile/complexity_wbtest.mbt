///|
test "format_decimal rounds, pads, and keeps non-finite values" {
  assert_eq(format_decimal(0.25, 4), "0.2500")
  assert_eq(format_decimal(2.5, 0), "3")
  assert_eq(format_decimal(-1.234, 2), "-1.23")
  assert_eq(format_decimal(-0.001, 2), "0.00")
  assert_eq(format_decimal(0.0 / 0.0, 2), "NaN")
  assert_eq(format_percent(0.123), "12.3%")
}
