///|
/// Snapshot of connection-level health and request outcomes.
pub struct ConnectionHealth {
  opened_at : Int64
  mut last_activity : Int64
  mut heartbeats_sent : Int
  mut heartbeats_received : Int
  mut requests : Int
  mut request_failures : Int
  mut bytes_read : Int64
  mut bytes_written : Int64
} derive(Debug)

///|
pub extend ConnectionHealth with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Creates a health tracker at a supplied monotonic timestamp.
pub fn ConnectionHealth::new(now_ms : Int64) -> ConnectionHealth {
  {
    opened_at: now_ms,
    last_activity: now_ms,
    heartbeats_sent: 0,
    heartbeats_received: 0,
    requests: 0,
    request_failures: 0,
    bytes_read: 0L,
    bytes_written: 0L,
  }
}

///|
pub fn ConnectionHealth::opened_at(self : ConnectionHealth) -> Int64 {
  self.opened_at
}

///|
pub fn ConnectionHealth::last_activity(self : ConnectionHealth) -> Int64 {
  self.last_activity
}

///|
pub fn ConnectionHealth::heartbeats_sent(self : ConnectionHealth) -> Int {
  self.heartbeats_sent
}

///|
pub fn ConnectionHealth::heartbeats_received(self : ConnectionHealth) -> Int {
  self.heartbeats_received
}

///|
pub fn ConnectionHealth::requests(self : ConnectionHealth) -> Int {
  self.requests
}

///|
pub fn ConnectionHealth::request_failures(self : ConnectionHealth) -> Int {
  self.request_failures
}

///|
pub fn ConnectionHealth::bytes_read(self : ConnectionHealth) -> Int64 {
  self.bytes_read
}

///|
pub fn ConnectionHealth::bytes_written(self : ConnectionHealth) -> Int64 {
  self.bytes_written
}

///|
pub fn ConnectionHealth::record_read(
  self : ConnectionHealth,
  now_ms : Int64,
  bytes : Int,
) -> Unit raise ProtocolError {
  if bytes < 0 {
    raise InvalidOption("read byte count cannot be negative")
  }
  self.last_activity = now_ms
  self.bytes_read += bytes.to_int64()
}

///|
pub fn ConnectionHealth::record_write(
  self : ConnectionHealth,
  now_ms : Int64,
  bytes : Int,
) -> Unit raise ProtocolError {
  if bytes < 0 {
    raise InvalidOption("write byte count cannot be negative")
  }
  self.last_activity = now_ms
  self.bytes_written += bytes.to_int64()
}

///|
pub fn ConnectionHealth::record_request(
  self : ConnectionHealth,
  now_ms : Int64,
) -> Unit {
  self.last_activity = now_ms
  self.requests += 1
}

///|
pub fn ConnectionHealth::record_failure(
  self : ConnectionHealth,
  now_ms : Int64,
) -> Unit {
  self.last_activity = now_ms
  self.request_failures += 1
}

///|
pub fn ConnectionHealth::record_heartbeat_sent(
  self : ConnectionHealth,
  now_ms : Int64,
) -> Unit {
  self.last_activity = now_ms
  self.heartbeats_sent += 1
}

///|
pub fn ConnectionHealth::record_heartbeat_received(
  self : ConnectionHealth,
  now_ms : Int64,
) -> Unit {
  self.last_activity = now_ms
  self.heartbeats_received += 1
}

///|
/// Returns true when activity is within the supplied liveness window.
pub fn ConnectionHealth::is_alive(
  self : ConnectionHealth,
  now_ms : Int64,
  timeout_ms : Int64,
) -> Bool {
  timeout_ms >= 0L &&
  now_ms >= self.last_activity &&
  now_ms - self.last_activity <= timeout_ms
}

///|
/// Duration since the last observed activity.
pub fn ConnectionHealth::idle_for(
  self : ConnectionHealth,
  now_ms : Int64,
) -> Int64 {
  if now_ms <= self.last_activity {
    0L
  } else {
    now_ms - self.last_activity
  }
}

///|
/// Connection age measured from the supplied monotonic clock.
pub fn ConnectionHealth::age(self : ConnectionHealth, now_ms : Int64) -> Int64 {
  if now_ms <= self.opened_at {
    0L
  } else {
    now_ms - self.opened_at
  }
}

///|
/// Failure ratio in basis points, avoiding floating-point metrics.
pub fn ConnectionHealth::failure_rate_basis_points(
  self : ConnectionHealth,
) -> Int {
  if self.requests == 0 {
    0
  } else {
    self.request_failures * 10_000 / self.requests
  }
}

///|
/// Consumer-side in-flight window independent of broker connection details.
pub struct DeliveryWindow {
  limit : Int
  mut in_flight : Int
  mut accepted : Int
  mut settled : Int
} derive(Debug)

///|
pub extend DeliveryWindow with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn DeliveryWindow::new(limit : Int) -> DeliveryWindow raise ProtocolError {
  if limit < 1 || limit > 2_500 {
    raise InvalidOption("delivery window must be between 1 and 2500")
  }
  { limit, in_flight: 0, accepted: 0, settled: 0, }
}

///|
pub fn DeliveryWindow::limit(self : DeliveryWindow) -> Int {
  self.limit
}

///|
pub fn DeliveryWindow::in_flight(self : DeliveryWindow) -> Int {
  self.in_flight
}

///|
pub fn DeliveryWindow::accepted(self : DeliveryWindow) -> Int {
  self.accepted
}

///|
pub fn DeliveryWindow::settled(self : DeliveryWindow) -> Int {
  self.settled
}

///|
/// Reserves one delivery slot, returning false when the window is full.
pub fn DeliveryWindow::try_accept(self : DeliveryWindow) -> Bool {
  if self.in_flight >= self.limit {
    false
  } else {
    self.in_flight += 1
    self.accepted += 1
    true
  }
}

///|
/// Settles one delivery exactly when a slot is occupied.
pub fn DeliveryWindow::settle(self : DeliveryWindow) -> Bool {
  if self.in_flight == 0 {
    false
  } else {
    self.in_flight -= 1
    self.settled += 1
    true
  }
}

///|
/// Returns available capacity for issuing an RDY command.
pub fn DeliveryWindow::available(self : DeliveryWindow) -> Int {
  self.limit - self.in_flight
}

///|
/// Clears in-flight state after a connection is lost; accepted totals remain.
pub fn DeliveryWindow::reset(self : DeliveryWindow) -> Int {
  let lost = self.in_flight
  self.in_flight = 0
  lost
}
