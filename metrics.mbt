///|
/// A small fixed-bucket latency histogram for producer and consumer metrics.
pub struct LatencyHistogram {
  mut samples : Int
  mut total_ms : Int64
  mut minimum_ms : Int
  mut maximum_ms : Int
  buckets : Array[Int]
} derive(Debug)

///|
pub extend LatencyHistogram with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Creates an empty histogram with eleven practical latency buckets.
pub fn LatencyHistogram::new() -> LatencyHistogram {
  {
    samples: 0,
    total_ms: 0,
    minimum_ms: 0,
    maximum_ms: 0,
    buckets: Array::make(11, 0),
  }
}

///|
/// Adds a non-negative observation to the histogram.
pub fn LatencyHistogram::observe(
  self : LatencyHistogram,
  latency_ms : Int,
) -> Unit raise ProtocolError {
  if latency_ms < 0 {
    raise InvalidOption("latency cannot be negative")
  }
  if self.samples == 0 {
    self.minimum_ms = latency_ms
    self.maximum_ms = latency_ms
  } else {
    self.minimum_ms = if latency_ms < self.minimum_ms {
      latency_ms
    } else {
      self.minimum_ms
    }
    self.maximum_ms = if latency_ms > self.maximum_ms {
      latency_ms
    } else {
      self.maximum_ms
    }
  }
  self.samples += 1
  self.total_ms += latency_ms.to_int64()
  let bucket = if latency_ms <= 1 {
    0
  } else if latency_ms <= 5 {
    1
  } else if latency_ms <= 10 {
    2
  } else if latency_ms <= 25 {
    3
  } else if latency_ms <= 50 {
    4
  } else if latency_ms <= 100 {
    5
  } else if latency_ms <= 250 {
    6
  } else if latency_ms <= 500 {
    7
  } else if latency_ms <= 1_000 {
    8
  } else if latency_ms <= 5_000 {
    9
  } else {
    10
  }
  self.buckets[bucket] += 1
}

///|
pub fn LatencyHistogram::count(self : LatencyHistogram) -> Int {
  self.samples
}

///|
pub fn LatencyHistogram::total(self : LatencyHistogram) -> Int64 {
  self.total_ms
}

///|
pub fn LatencyHistogram::minimum(self : LatencyHistogram) -> Int {
  self.minimum_ms
}

///|
pub fn LatencyHistogram::maximum(self : LatencyHistogram) -> Int {
  self.maximum_ms
}

///|
/// Returns the arithmetic mean, or zero for an empty histogram.
pub fn LatencyHistogram::mean(self : LatencyHistogram) -> Int {
  if self.samples == 0 {
    0
  } else {
    (self.total_ms / self.samples.to_int64()).to_int()
  }
}

///|
/// Returns the upper bound of the bucket containing the requested percentile.
pub fn LatencyHistogram::percentile(
  self : LatencyHistogram,
  percentile : Int,
) -> Int raise ProtocolError {
  if percentile < 0 || percentile > 100 {
    raise InvalidOption("percentile must be between 0 and 100")
  }
  if self.samples == 0 {
    return 0
  }
  let wanted = (self.samples * percentile + 99) / 100
  let wanted = if wanted < 1 { 1 } else { wanted }
  let limits = [1, 5, 10, 25, 50, 100, 250, 500, 1_000, 5_000, 2_147_483_647]
  let mut seen = 0
  for i in 0..<self.buckets.length() {
    seen += self.buckets[i]
    if seen >= wanted {
      return limits[i]
    }
  }
  self.maximum_ms
}

///|
/// Combines another histogram into this one.
pub fn LatencyHistogram::merge(
  self : LatencyHistogram,
  other : LatencyHistogram,
) -> Unit {
  if other.samples == 0 {
    return
  }
  if self.samples == 0 {
    self.minimum_ms = other.minimum_ms
    self.maximum_ms = other.maximum_ms
  } else {
    self.minimum_ms = if other.minimum_ms < self.minimum_ms {
      other.minimum_ms
    } else {
      self.minimum_ms
    }
    self.maximum_ms = if other.maximum_ms > self.maximum_ms {
      other.maximum_ms
    } else {
      self.maximum_ms
    }
  }
  self.samples += other.samples
  self.total_ms += other.total_ms
  for i in 0..<self.buckets.length() {
    self.buckets[i] += other.buckets[i]
  }
}

///|
/// Counters for an NSQ producer session.
pub struct ProducerMetrics {
  mut published : Int
  mut failed : Int
  mut bytes : Int64
  latency : LatencyHistogram
} derive(Debug)

///|
pub extend ProducerMetrics with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn ProducerMetrics::new() -> ProducerMetrics {
  { published: 0, failed: 0, bytes: 0, latency: LatencyHistogram::new(), }
}

///|
pub fn ProducerMetrics::record_success(
  self : ProducerMetrics,
  payload_bytes : Int,
  latency_ms : Int,
) -> Unit raise ProtocolError {
  self.published += 1
  self.bytes += payload_bytes.to_int64()
  self.latency.observe(latency_ms)
}

///|
pub fn ProducerMetrics::record_failure(self : ProducerMetrics) -> Unit {
  self.failed += 1
}

///|
pub fn ProducerMetrics::published(self : ProducerMetrics) -> Int {
  self.published
}

///|
pub fn ProducerMetrics::failed(self : ProducerMetrics) -> Int {
  self.failed
}

///|
pub fn ProducerMetrics::bytes(self : ProducerMetrics) -> Int64 {
  self.bytes
}

///|
pub fn ProducerMetrics::latency(self : ProducerMetrics) -> LatencyHistogram {
  self.latency
}
