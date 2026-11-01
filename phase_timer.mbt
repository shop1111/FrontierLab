///|
/// Wall-clock time spent in one named phase.
pub struct PhaseTiming {
  name : String
  ms : Double
} derive(Debug, Eq, ToJson)

///|
pub extend PhaseTiming with Debug::{to_repr}

///|
pub extend PhaseTiming with Eq::{not_equal, equal}

///|
pub extend PhaseTiming with ToJson::{to_json}

///|
/// Records how long each phase of a pipeline takes.
///
/// `clock` returns milliseconds as a `Double`. Phases usually run once, so
/// pass a sub-millisecond monotonic clock, for example
/// `@bench.monotonic_clock_end(start) / 1000.0`. The library never reads a
/// platform clock itself.
pub struct PhaseTimer {
  priv clock : () -> Double
  priv timings : Array[PhaseTiming]
}

///|
pub fn PhaseTimer::new(clock~ : () -> Double) -> PhaseTimer {
  { clock, timings: [], }
}

///|
/// Runs `body` and records its duration under `name`. A phase that raises is
/// not recorded.
pub fn[T] PhaseTimer::measure(
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
/// The recorded phases in the order they finished.
pub fn PhaseTimer::timings(self : PhaseTimer) -> Array[PhaseTiming] {
  self.timings.copy()
}

///|
pub fn PhaseTimer::total_ms(self : PhaseTimer) -> Double {
  self.timings.fold(init=0.0, fn(total, timing) { total + timing.ms })
}

///|
/// Renders the phases as a Markdown table with each phase's share.
pub fn PhaseTimer::report(self : PhaseTimer) -> String {
  let total = self.total_ms()
  let out = StringBuilder()
  out.write_string("| phase | ms | share |\n|---|---:|---:|\n")
  for timing in self.timings {
    let share = if total > 0.0 { timing.ms / total } else { 0.0 }
    out.write_string(
      "| \{timing.name} | \{format_decimal(timing.ms, 3)} | \{format_percent(share)} |\n",
    )
  }
  out.write_string("| total | \{format_decimal(total, 3)} | |\n")
  out.to_string()
}

///|
fn[T] timed_phase(
  timer : PhaseTimer?,
  name : String,
  body : () -> T raise?,
) -> T raise? {
  match timer {
    Some(value) => value.measure(name, body)
    None => body()
  }
}
