///|
/// Wall-clock cost of running one algorithm at each `TraceLevel`.
///
/// Each level is repeated until it takes at least `min_ms` in total, so the
/// `*_runs` fields differ; times are milliseconds per run. The ratios compare
/// `Count` and `Full` against the untraced `Off` baseline and are 0 when the
/// baseline stayed below the clock resolution because `max_runs` was reached.
pub struct TracingOverhead {
  off_runs : Int32
  count_runs : Int32
  full_runs : Int32
  off_ms : Double
  count_ms : Double
  full_ms : Double
  count_ratio : Double
  full_ratio : Double
  steps : Int32
  json_length : Int32
  full_us_per_step : Double
} derive(Debug, Eq, ToJson)

///|
pub extend TracingOverhead with Debug::{to_repr}

///|
pub extend TracingOverhead with Eq::{not_equal, equal}

///|
pub extend TracingOverhead with ToJson::{to_json}

///|
/// Measures how much tracing slows `algorithm` on `input`.
///
/// `clock` returns milliseconds, for example `@env.now`. For each level the
/// run count doubles until the runs take at least `min_ms` or reach
/// `max_runs`. `Full` timing includes `finish`, so it covers producing a
/// validated trace.
pub fn[T : Show] measure_tracing_overhead(
  input : Array[T],
  algorithm : (TracedArray[T]) -> Unit,
  clock~ : () -> UInt64,
  min_ms~ : Int32 = 50,
  max_runs~ : Int32 = 65536,
  options~ : TraceOptions = TraceOptions::default(),
) -> TracingOverhead raise TraceError {
  fn timed(level : TraceLevel, runs : Int32) -> Double raise TraceError {
    let start = clock()
    for _ in 0..<runs {
      let array = TracedArray::new(input, level~, options~)
      algorithm(array)
      if level == Full {
        ignore(array.finish())
      }
    }
    (clock() - start).to_double()
  }

  fn measure(level : TraceLevel) -> (Int32, Double) raise TraceError {
    let mut runs = 1
    let mut total = timed(level, runs)
    while total < min_ms.to_double() && runs < max_runs {
      runs = runs * 2
      total = timed(level, runs)
    }
    (runs, total / runs.to_double())
  }

  let (off_runs, off_ms) = measure(Off)
  let (count_runs, count_ms) = measure(Count)
  let (full_runs, full_ms) = measure(Full)
  let sample = TracedArray::new(input, options~)
  algorithm(sample)
  let trace = sample.finish()
  let steps = trace.steps.length()
  {
    off_runs,
    count_runs,
    full_runs,
    off_ms,
    count_ms,
    full_ms,
    count_ratio: if off_ms > 0.0 {
      count_ms / off_ms
    } else {
      0.0
    },
    full_ratio: if off_ms > 0.0 {
      full_ms / off_ms
    } else {
      0.0
    },
    steps,
    json_length: trace.encode_json().length(),
    full_us_per_step: (full_ms - off_ms) * 1000.0 / steps.to_double(),
  }
}

///|
/// Renders the measurement as Markdown.
pub fn TracingOverhead::report(self : TracingOverhead) -> String {
  let out = StringBuilder()
  out.write_string("## Tracing overhead\n\n")
  out.write_string("| level | runs | ms per run | vs Off |\n")
  out.write_string("|---|---:|---:|---:|\n")
  out.write_string(
    "| Off | \{self.off_runs} | \{format_decimal(self.off_ms, 4)} | 1.00x |\n",
  )
  out.write_string(
    "| Count | \{self.count_runs} | \{format_decimal(self.count_ms, 4)} | \{format_decimal(self.count_ratio, 2)}x |\n",
  )
  out.write_string(
    "| Full | \{self.full_runs} | \{format_decimal(self.full_ms, 4)} | \{format_decimal(self.full_ratio, 2)}x |\n",
  )
  out.write_string(
    "\nFull trace: \{self.steps} steps, \{self.json_length} JSON characters, \{format_decimal(self.full_us_per_step, 2)} µs of overhead per step.\n",
  )
  out.to_string()
}
