///|
/// Successful request ratio in basis points.
pub fn ConnectionHealth::success_rate_basis_points(
  self : ConnectionHealth,
) -> Int {
  10_000 - self.failure_rate_basis_points()
}

///|
/// Records a successful request and updates its activity timestamp.
pub fn ConnectionHealth::record_success(
  self : ConnectionHealth,
  now_ms : Int64,
) -> Unit {
  self.record_request(now_ms)
}

///|
/// Current utilization in basis points for dashboards.
pub fn DeliveryWindow::utilization_basis_points(self : DeliveryWindow) -> Int {
  self.in_flight * 10_000 / self.limit
}

///|
test "health ratios and delivery utilization are stable" {
  let health = ConnectionHealth::new(0L)
  health.record_request(1L)
  health.record_failure(2L)
  assert_eq(health.success_rate_basis_points(), 0)
  let window = DeliveryWindow::new(4)
  assert_true(window.try_accept())
  assert_eq(window.utilization_basis_points(), 2_500)
  ignore(window.reset())
  assert_eq(window.utilization_basis_points(), 0)
}

///|
test "successful requests update health activity" {
  let health = ConnectionHealth::new(10L)
  health.record_success(20L)
  assert_eq(health.requests(), 1)
  assert_eq(health.last_activity(), 20L)
}
