///|
/// Wall-clock time spent in one named CLI phase.
#derive(ToJson)
priv struct PhaseTiming {
  name : String
  ms : Double
}

///|
/// Records how long each phase of `diagnose --timings` takes.
///
/// `clock` returns milliseconds as a `Double`.
priv struct PhaseTimer {
  clock : () -> Double
  timings : Array[PhaseTiming]
}

///|
fn PhaseTimer::new(clock~ : () -> Double) -> PhaseTimer {
  { clock, timings: [], }
}

///|
/// Runs `body` and records its duration under `name`. A phase that raises is
/// not recorded.
fn[T] PhaseTimer::measure(
  self : PhaseTimer,
  name : String,
  body : () -> T raise?,
) -> T raise? {
  let start = (self.clock)()
  let value = body()
  let elapsed = (self.clock)() - start
  self.timings.push({ name, ms: if elapsed > 0.0 { elapsed } else { 0.0 }, })
  value
}

///|
fn PhaseTimer::total_ms(self : PhaseTimer) -> Double {
  self.timings.fold(init=0.0, fn(total, timing) { total + timing.ms })
}

///|
/// Renders the phases as a Markdown table with each phase's share.
fn PhaseTimer::report(self : PhaseTimer) -> String {
  let total = self.total_ms()
  let out = StringBuilder()
  out.write_string("| phase | ms | share |\n|---|---:|---:|\n")
  for timing in self.timings {
    let share = if total > 0.0 { timing.ms / total } else { 0.0 }
    out.write_string(
      "| \{timing.name} | \{fixed_decimal(timing.ms, 3)} | \{fixed_decimal(share * 100.0, 1)}% |\n",
    )
  }
  out.write_string("| total | \{fixed_decimal(total, 3)} | |\n")
  out.to_string()
}

///|
/// Formats a non-negative value with a fixed number of decimals, rounding
/// half up.
fn fixed_decimal(value : Double, digits : Int32) -> String {
  let mut scale = 1.0
  for _ in 0..<digits {
    scale = scale * 10.0
  }
  let text = (value * scale + 0.5).floor().to_int64().to_string()
  let padded = if text.length() <= digits {
    "0".repeat(digits - text.length() + 1) + text
  } else {
    text
  }
  let whole = padded.length() - digits
  if digits == 0 {
    padded
  } else {
    "\{padded[:whole]}.\{padded[whole:]}"
  }
}
