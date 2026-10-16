///|
test "connection health tracks activity and liveness" {
  let health = @moon-nsq.ConnectionHealth::new(100L)
  assert_true(health.is_alive(100L, 0L))
  health.record_read(120L, 10)
  health.record_write(130L, 5)
  health.record_request(140L)
  health.record_failure(150L)
  health.record_heartbeat_sent(160L)
  health.record_heartbeat_received(170L)
  assert_eq(health.bytes_read(), 10L)
  assert_eq(health.bytes_written(), 5L)
  assert_eq(health.requests(), 1)
  assert_eq(health.request_failures(), 1)
  assert_false(health.is_alive(200L, 29L))
  assert_true(health.is_alive(200L, 30L))
  assert_eq(health.idle_for(200L), 30L)
  assert_eq(health.age(200L), 100L)
  assert_eq(health.failure_rate_basis_points(), 10_000)
}

///|
test "delivery window enforces and resets capacity" {
  let window = @moon-nsq.DeliveryWindow::new(2)
  assert_true(window.try_accept())
  assert_true(window.try_accept())
  assert_false(window.try_accept())
  assert_eq(window.available(), 0)
  assert_true(window.settle())
  assert_eq(window.available(), 1)
  assert_eq(window.reset(), 1)
  assert_false(window.settle())
  assert_eq(window.accepted(), 2)
}
