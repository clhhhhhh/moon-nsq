///|
test "latency histogram tracks buckets and summary" {
  let histogram = @moon-nsq.LatencyHistogram::new()
  for value in [0, 1, 5, 6, 20, 50, 101, 700, 2_000, 8_000] {
    histogram.observe(value)
  }
  assert_eq(histogram.count(), 10)
  assert_eq(histogram.minimum(), 0)
  assert_eq(histogram.maximum(), 8_000)
  assert_eq(histogram.total(), 10_883L)
  assert_eq(histogram.mean(), 1_088)
  assert_eq(histogram.percentile(50), 25)
  assert_eq(histogram.percentile(99), 2_147_483_647)
}

///|
test "histograms merge without losing observations" {
  let left = @moon-nsq.LatencyHistogram::new()
  left.observe(10)
  let right = @moon-nsq.LatencyHistogram::new()
  right.observe(100)
  right.observe(200)
  left.merge(right)
  assert_eq(left.count(), 3)
  assert_eq(left.mean(), 103)
  assert_eq(left.minimum(), 10)
  assert_eq(left.maximum(), 200)
}

///|
test "producer metrics count bytes and failures" {
  let metrics = @moon-nsq.ProducerMetrics::new()
  metrics.record_success(5, 10)
  metrics.record_failure()
  assert_eq(metrics.published(), 1)
  assert_eq(metrics.failed(), 1)
  assert_eq(metrics.bytes(), 5L)
}
