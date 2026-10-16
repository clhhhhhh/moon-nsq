///|
/// A lease returned by the endpoint pool before opening a TCP connection.
pub struct ConnectionLease {
  priv owner : PoolStats
  endpoint : ProducerEndpoint
  generation : Int
  mut released : Bool
} derive(Debug)

///|
pub extend ConnectionLease with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn ConnectionLease::endpoint(self : ConnectionLease) -> ProducerEndpoint {
  self.endpoint
}

///|
pub fn ConnectionLease::generation(self : ConnectionLease) -> Int {
  self.generation
}

///|
pub fn ConnectionLease::is_released(self : ConnectionLease) -> Bool {
  self.released
}

///|
/// Statistics for a pool's endpoint selection decisions.
pub struct PoolStats {
  mut leases : Int
  mut releases : Int
  mut failures : Int
  mut successes : Int
  mut rejected : Int
} derive(Debug)

///|
pub extend PoolStats with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn PoolStats::new() -> PoolStats {
  { leases: 0, releases: 0, failures: 0, successes: 0, rejected: 0, }
}

///|
pub fn PoolStats::leases(self : PoolStats) -> Int {
  self.leases
}

///|
pub fn PoolStats::releases(self : PoolStats) -> Int {
  self.releases
}

///|
pub fn PoolStats::failures(self : PoolStats) -> Int {
  self.failures
}

///|
pub fn PoolStats::successes(self : PoolStats) -> Int {
  self.successes
}

///|
pub fn PoolStats::rejected(self : PoolStats) -> Int {
  self.rejected
}

///|
/// A bounded endpoint selector suitable for producers and lookup refreshes.
pub struct ConnectionPool {
  routing : RoutingTable
  mut generation : Int
  max_connections : Int
  mut active : Int
  stats : PoolStats
} derive(Debug)

///|
pub extend ConnectionPool with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn ConnectionPool::new(
  producers : Array[ProducerEndpoint],
  max_connections? : Int = 16,
) -> ConnectionPool raise ProtocolError {
  if max_connections < 1 || max_connections > 10_000 {
    raise InvalidOption("max_connections must be between 1 and 10000")
  }
  {
    routing: RoutingTable::new(producers),
    generation: 0,
    max_connections,
    active: 0,
    stats: PoolStats::new(),
  }
}

///|
pub fn ConnectionPool::capacity(self : ConnectionPool) -> Int {
  self.max_connections
}

///|
pub fn ConnectionPool::active(self : ConnectionPool) -> Int {
  self.active
}

///|
pub fn ConnectionPool::stats(self : ConnectionPool) -> PoolStats {
  self.stats
}

///|
/// Reserves an endpoint, rejecting leases once the configured bound is full.
pub fn ConnectionPool::lease(
  self : ConnectionPool,
  now_ms : Int64,
) -> ConnectionLease raise ProtocolError {
  if self.active >= self.max_connections {
    self.stats.rejected += 1
    raise InvalidState("connection pool is at capacity")
  }
  self.active += 1
  self.stats.leases += 1
  {
    endpoint: self.routing.choose(now_ms),
    owner: self.stats,
    generation: self.generation,
    released: false,
  }
}

///|
/// Releases a lease exactly once.
pub fn ConnectionPool::release(
  self : ConnectionPool,
  lease : ConnectionLease,
) -> Unit {
  if physical_equal(lease.owner, self.stats) && !lease.released {
    lease.released = true
    if self.active > 0 {
      self.active -= 1
    }
    self.stats.releases += 1
  }
}

///|
pub fn ConnectionPool::mark_failure(
  self : ConnectionPool,
  lease : ConnectionLease,
  now_ms : Int64,
) -> Bool {
  if !physical_equal(lease.owner, self.stats) ||
    lease.released ||
    lease.generation != self.generation {
    return false
  }
  self.stats.failures += 1
  self.routing.mark_failure(lease.endpoint().address(), now_ms)
}

///|
pub fn ConnectionPool::mark_success(
  self : ConnectionPool,
  lease : ConnectionLease,
) -> Bool {
  if !physical_equal(lease.owner, self.stats) ||
    lease.released ||
    lease.generation != self.generation {
    return false
  }
  self.stats.successes += 1
  self.routing.mark_success(lease.endpoint().address())
}

///|
/// Replaces discovery results and invalidates old lease generations.
pub fn ConnectionPool::refresh(
  self : ConnectionPool,
  producers : Array[ProducerEndpoint],
) -> Unit raise ProtocolError {
  self.routing.replace(producers)
  self.generation += 1
}
