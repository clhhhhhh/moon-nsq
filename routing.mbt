///|
/// Health state tracked for one discovered NSQ producer.
pub struct ProducerHealth {
  endpoint : ProducerEndpoint
  mut failures : Int
  mut successes : Int
  mut last_failure_ms : Int64
  mut healthy : Bool
} derive(Debug)

///|
pub extend ProducerHealth with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Creates a healthy endpoint record.
pub fn ProducerHealth::new(endpoint : ProducerEndpoint) -> ProducerHealth {
  { endpoint, failures: 0, successes: 0, last_failure_ms: 0L, healthy: true, }
}

///|
pub fn ProducerHealth::endpoint(self : ProducerHealth) -> ProducerEndpoint {
  self.endpoint
}

///|
pub fn ProducerHealth::is_healthy(self : ProducerHealth) -> Bool {
  self.healthy
}

///|
pub fn ProducerHealth::failures(self : ProducerHealth) -> Int {
  self.failures
}

///|
/// Marks a failed connection and records the time for cooldown decisions.
pub fn ProducerHealth::mark_failure(
  self : ProducerHealth,
  now_ms : Int64,
) -> Unit {
  self.failures += 1
  self.last_failure_ms = now_ms
  self.healthy = false
}

///|
/// Marks a successful request and clears the failure state.
pub fn ProducerHealth::mark_success(self : ProducerHealth) -> Unit {
  self.successes += 1
  self.failures = 0
  self.healthy = true
}

///|
/// Re-enables an endpoint after its cooldown has elapsed.
pub fn ProducerHealth::recover_if_ready(
  self : ProducerHealth,
  now_ms : Int64,
  cooldown_ms : Int64,
) -> Bool {
  if !self.healthy && now_ms - self.last_failure_ms >= cooldown_ms {
    self.healthy = true
    true
  } else {
    self.healthy
  }
}

///|
/// Round-robin routing table that skips unhealthy producers when possible.
pub struct RoutingTable {
  mut entries : Array[ProducerHealth]
  mut cursor : Int
  cooldown_ms : Int64
} derive(Debug)

///|
pub extend RoutingTable with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn RoutingTable::new(
  producers : Array[ProducerEndpoint],
  cooldown_ms? : Int64 = 5_000L,
) -> RoutingTable raise ProtocolError {
  if producers.length() == 0 {
    raise InvalidOption("routing table requires at least one producer")
  }
  if cooldown_ms < 0L {
    raise InvalidOption("routing cooldown cannot be negative")
  }
  let entries = Array::make(
    producers.length(),
    ProducerHealth::new(producers[0]),
  )
  for i in 0..<producers.length() {
    entries[i] = ProducerHealth::new(producers[i])
  }
  { entries, cursor: 0, cooldown_ms, }
}

///|
pub fn RoutingTable::length(self : RoutingTable) -> Int {
  self.entries.length()
}

///|
/// Chooses the next healthy endpoint and advances the cursor.
pub fn RoutingTable::choose(
  self : RoutingTable,
  now_ms : Int64,
) -> ProducerEndpoint {
  let length = self.entries.length()
  for offset in 0..<length {
    let index = (self.cursor + offset) % length
    let health = self.entries[index]
    if health.recover_if_ready(now_ms, self.cooldown_ms) {
      self.cursor = (index + 1) % length
      return health.endpoint()
    }
  }
  let fallback = self.entries[self.cursor]
  self.cursor = (self.cursor + 1) % length
  fallback.endpoint()
}

///|
pub fn RoutingTable::mark_failure(
  self : RoutingTable,
  address : String,
  now_ms : Int64,
) -> Bool {
  for entry in self.entries {
    if entry.endpoint().address() == address {
      entry.mark_failure(now_ms)
      return true
    }
  }
  false
}

///|
pub fn RoutingTable::mark_success(
  self : RoutingTable,
  address : String,
) -> Bool {
  for entry in self.entries {
    if entry.endpoint().address() == address {
      entry.mark_success()
      return true
    }
  }
  false
}

///|
/// Replaces endpoints while retaining no stale health state.
pub fn RoutingTable::replace(
  self : RoutingTable,
  producers : Array[ProducerEndpoint],
) -> Unit raise ProtocolError {
  if producers.length() == 0 {
    raise InvalidOption("routing table requires at least one producer")
  }
  self.entries = Array::make(
    producers.length(),
    ProducerHealth::new(producers[0]),
  )
  for i in 0..<producers.length() {
    self.entries[i] = ProducerHealth::new(producers[i])
  }
  self.cursor = 0
}
