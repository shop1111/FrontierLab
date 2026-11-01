///|
/// A growth class describing how an operation count scales with input size.
pub(all) enum ComplexityClass {
  Constant
  Logarithmic
  Linear
  Linearithmic
  Quadratic
  Cubic
  Exponential
} derive(Debug, Eq, ToJson)

///|
pub extend ComplexityClass with Debug::{to_repr}

///|
pub extend ComplexityClass with Eq::{not_equal, equal}

///|
pub extend ComplexityClass with ToJson::{to_json}

///|
let complexity_classes : Array[ComplexityClass] = [
  Constant,
  Logarithmic,
  Linear,
  Linearithmic,
  Quadratic,
  Cubic,
  Exponential,
]

///|
pub fn ComplexityClass::label(self : ComplexityClass) -> String {
  match self {
    Constant => "O(1)"
    Logarithmic => "O(log n)"
    Linear => "O(n)"
    Linearithmic => "O(n log n)"
    Quadratic => "O(n^2)"
    Cubic => "O(n^3)"
    Exponential => "O(2^n)"
  }
}

///|
/// Parses a label such as `O(n log n)`, `n*log(n)`, or `n^2`. Case, spaces, and
/// the `O(...)` wrapper are optional, and `**`, `²`, and `³` spell powers.
pub fn ComplexityClass::parse(text : String) -> ComplexityClass? {
  let compact = StringBuilder()
  for ch in text.to_lower().replace_all(old="**", new="^") {
    match ch {
      ' ' | '\t' | '*' | '(' | ')' => ()
      '²' => compact.write_string("^2")
      '³' => compact.write_string("^3")
      _ => compact.write_char(ch)
    }
  }
  let key = compact.to_string()
  match key.strip_prefix("o").unwrap_or(key[:]) {
    "1" => Some(Constant)
    "logn" | "lgn" => Some(Logarithmic)
    "n" => Some(Linear)
    "nlogn" | "nlgn" => Some(Linearithmic)
    "n^2" | "nn" => Some(Quadratic)
    "n^3" => Some(Cubic)
    "2^n" => Some(Exponential)
    _ => None
  }
}

///|
/// Evaluates the growth function at `n`. Logarithms use base 2 and are at
/// least 1, so small inputs do not divide by zero.
pub fn ComplexityClass::evaluate(self : ComplexityClass, n : Int32) -> Double {
  let x = n.to_double()
  let lg = if n < 2 { 1.0 } else { @math.log2(x) }
  match self {
    Constant => 1.0
    Logarithmic => lg
    Linear => x
    Linearithmic => x * lg
    Quadratic => x * x
    Cubic => x * x * x
    Exponential => @math.pow(2.0, x)
  }
}

///|
/// The operation count a complexity profile fits.
pub(all) enum CostMetric {
  Compares
  Swaps
  Reads
  Writes
  /// Compares, swaps, reads, and writes together.
  Total
} derive(Debug, Eq, ToJson)

///|
pub extend CostMetric with Debug::{to_repr}

///|
pub extend CostMetric with Eq::{not_equal, equal}

///|
pub extend CostMetric with ToJson::{to_json}

///|
pub fn CostMetric::name(self : CostMetric) -> String {
  match self {
    Compares => "compares"
    Swaps => "swaps"
    Reads => "reads"
    Writes => "writes"
    Total => "total"
  }
}

///|
pub fn CostMetric::cost(self : CostMetric, counts : OperationCounts) -> Int32 {
  match self {
    Compares => counts.compares
    Swaps => counts.swaps
    Reads => counts.reads
    Writes => counts.writes
    Total => counts.compares + counts.swaps + counts.reads + counts.writes
  }
}

///|
/// Operation counts measured for one input size.
pub struct ComplexitySample {
  size : Int32
  counts : OperationCounts
  cost : Int32
} derive(Debug, Eq, ToJson)

///|
pub extend ComplexitySample with Debug::{to_repr}

///|
pub extend ComplexitySample with Eq::{not_equal, equal}

///|
pub extend ComplexitySample with ToJson::{to_json}

///|
/// `cost ≈ coefficient · class(n)`. `error` is the root-mean-square relative
/// residual over all samples, so 0.05 means a typical 5% deviation.
pub struct ComplexityFit {
  class : ComplexityClass
  coefficient : Double
  error : Double
} derive(Debug, Eq, ToJson)

///|
pub extend ComplexityFit with Debug::{to_repr}

///|
pub extend ComplexityFit with Eq::{not_equal, equal}

///|
pub extend ComplexityFit with ToJson::{to_json}

///|
/// Measured operation counts over increasing input sizes with every growth
/// class fitted to them. `fits` is ordered from best to worst; `exponent` is
/// the least-squares slope of log(cost) against log(n).
pub struct ComplexityProfile {
  metric : CostMetric
  samples : Array[ComplexitySample]
  fits : Array[ComplexityFit]
  best : ComplexityFit
  exponent : Double
} derive(Debug, Eq, ToJson)

///|
pub extend ComplexityProfile with Debug::{to_repr}

///|
pub extend ComplexityProfile with Eq::{not_equal, equal}

///|
pub extend ComplexityProfile with ToJson::{to_json}

///|
/// Runs `run` for each size and fits growth classes to the chosen cost.
/// Sizes must be positive and strictly increasing, with at least two of them.
pub fn profile_complexity(
  sizes : Array[Int32],
  run : (Int32) -> OperationCounts,
  metric~ : CostMetric = Total,
) -> ComplexityProfile raise TraceError {
  if sizes.length() < 2 {
    raise InvalidStep("complexity profiling needs at least two sizes")
  }
  for i, size in sizes {
    if size <= 0 {
      raise InvalidStep("complexity profiling sizes must be positive")
    }
    if i > 0 && size <= sizes[i - 1] {
      raise InvalidStep(
        "complexity profiling sizes must be strictly increasing",
      )
    }
  }
  let samples = sizes.map(fn(size) {
    let counts = run(size)
    { size, counts, cost: metric.cost(counts), }
  })
  if samples.all(fn(sample) { sample.cost == 0 }) {
    let none = { class: Constant, coefficient: 0.0, error: 0.0, }
    return { metric, samples, fits: [none], best: none, exponent: 0.0, }
  }
  let fits = complexity_classes.filter_map(fn(class) {
    fit_complexity(samples, class)
  })
  // Fits within rounding of each other are ordered by slower growth first,
  // because the measured sizes cannot tell them apart.
  fits.sort_by(fn(left, right) {
    if (left.error - right.error).abs() <= 1.0e-9 {
      growth_rank(left.class).compare(growth_rank(right.class))
    } else {
      left.error.compare(right.error)
    }
  })
  { metric, samples, fits, best: fits[0], exponent: growth_exponent(samples), }
}

///|
fn growth_rank(class : ComplexityClass) -> Int32 {
  complexity_classes.search(class).unwrap()
}

///|
/// Profiles an algorithm written against `TracedArray`. Each size gets a
/// fresh input and runs at `TraceLevel::Count`, so no trace is recorded.
pub fn[T : Show] profile_traced_array(
  sizes : Array[Int32],
  input : (Int32) -> Array[T],
  algorithm : (TracedArray[T]) -> Unit,
  metric~ : CostMetric = Total,
) -> ComplexityProfile raise TraceError {
  profile_complexity(
    sizes,
    fn(size) {
      let array = TracedArray::new(input(size), level=Count)
      algorithm(array)
      array.counts()
    },
    metric~,
  )
}

///|
/// Fits `cost ≈ c · class(n)` by least squares on relative residuals, so
/// small and large inputs weigh equally. Returns `None` when the class
/// overflows at the measured sizes.
fn fit_complexity(
  samples : Array[ComplexitySample],
  class : ComplexityClass,
) -> ComplexityFit? {
  let values = []
  for sample in samples {
    let value = class.evaluate(sample.size)
    if value.is_inf() || value.is_nan() {
      return None
    }
    values.push(value)
  }
  let mut numerator = 0.0
  let mut denominator = 0.0
  for i, sample in samples {
    let ratio = values[i] / cost_scale(sample.cost)
    numerator += ratio
    denominator += ratio * ratio
  }
  let coefficient = numerator / denominator
  let mut squared = 0.0
  for i, sample in samples {
    let residual = (sample.cost.to_double() - coefficient * values[i]) /
      cost_scale(sample.cost)
    squared += residual * residual
  }
  Some({
    class,
    coefficient,
    error: (squared / samples.length().to_double()).sqrt(),
  })
}

///|
fn cost_scale(cost : Int32) -> Double {
  if cost > 0 {
    cost.to_double()
  } else {
    1.0
  }
}

///|
fn growth_exponent(samples : Array[ComplexitySample]) -> Double {
  let xs = []
  let ys = []
  for sample in samples {
    if sample.cost > 0 {
      xs.push(@math.ln(sample.size.to_double()))
      ys.push(@math.ln(sample.cost.to_double()))
    }
  }
  if xs.length() < 2 {
    return 0.0
  }
  let count = xs.length().to_double()
  let mean_x = xs.fold(init=0.0, fn(sum, x) { sum + x }) / count
  let mean_y = ys.fold(init=0.0, fn(sum, y) { sum + y }) / count
  let mut covariance = 0.0
  let mut variance = 0.0
  for i, x in xs {
    covariance += (x - mean_x) * (ys[i] - mean_y)
    variance += (x - mean_x) * (x - mean_x)
  }
  covariance / variance
}

///|
/// Returns the samples whose cost exceeds `factor · bound(n)`. An empty
/// result means the bound holds at every measured size, which makes this
/// usable as a deterministic complexity check in tests and CI.
pub fn ComplexityProfile::check_bound(
  self : ComplexityProfile,
  bound : ComplexityClass,
  factor~ : Double,
) -> Array[ComplexitySample] {
  self.samples.filter(fn(sample) {
    sample.cost.to_double() > factor * bound.evaluate(sample.size)
  })
}

///|
/// Renders the samples and fits as Markdown.
pub fn ComplexityProfile::report(self : ComplexityProfile) -> String {
  let out = StringBuilder()
  out.write_string("## Complexity profile (\{self.metric.name()})\n\n")
  out.write_string("| n | compares | swaps | reads | writes | cost |\n")
  out.write_string("|---:|---:|---:|---:|---:|---:|\n")
  for sample in self.samples {
    let counts = sample.counts
    out.write_string(
      "| \{sample.size} | \{counts.compares} | \{counts.swaps} | \{counts.reads} | \{counts.writes} | \{sample.cost} |\n",
    )
  }
  out.write_string(
    "\nBest fit: \{self.best.class.label()}, cost ≈ \{format_decimal(self.best.coefficient, 3)} · \{growth_term(self.best.class)} (relative error \{format_percent(self.best.error)}).\n",
  )
  out.write_string(
    "Empirical exponent: \{format_decimal(self.exponent, 2)}.\n\n",
  )
  out.write_string("| class | coefficient | relative error |\n")
  out.write_string("|---|---:|---:|\n")
  for fit in self.fits {
    out.write_string(
      "| \{fit.class.label()} | \{format_decimal(fit.coefficient, 4)} | \{format_percent(fit.error)} |\n",
    )
  }
  out.to_string()
}

///|
fn growth_term(class : ComplexityClass) -> String {
  match class {
    Constant => "1"
    Logarithmic => "log n"
    Linear => "n"
    Linearithmic => "n log n"
    Quadratic => "n^2"
    Cubic => "n^3"
    Exponential => "2^n"
  }
}

///|
fn format_percent(ratio : Double) -> String {
  format_decimal(ratio * 100.0, 1) + "%"
}

///|
/// Formats with a fixed number of decimals, rounding half away from zero.
fn format_decimal(value : Double, digits : Int32) -> String {
  if value.is_nan() || value.is_inf() {
    return value.to_string()
  }
  let negative = value < 0.0
  let scale = @math.pow(10.0, digits.to_double())
  let scaled = ((if negative { -value } else { value }) * scale + 0.5).floor()
  let text = scaled.to_int64().to_string()
  let padded = if text.length() <= digits {
    "0".repeat(digits - text.length() + 1) + text
  } else {
    text
  }
  let whole = padded.length() - digits
  let body = if digits == 0 {
    padded
  } else {
    "\{padded[:whole]}.\{padded[whole:]}"
  }
  if negative && scaled > 0.0 {
    "-" + body
  } else {
    body
  }
}
