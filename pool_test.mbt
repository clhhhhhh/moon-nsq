///|
test "pool enforces capacity and releases leases" {
  let a = @moon-nsq.ProducerEndpoint::new("a", 4150)
  let pool = @moon-nsq.ConnectionPool::new([a], max_connections=1)
  let lease = pool.lease(0L)
  assert_eq(pool.active(), 1)
  try pool.lease(1L) catch {
    _ => ()
  } noraise {
    _ => fail("pool exceeded capacity")
  }
  pool.release(lease)
  pool.release(lease)
  assert_eq(pool.active(), 0)
  assert_eq(pool.stats().releases(), 1)
}

///|
test "pool refresh advances lease generation" {
  let a = @moon-nsq.ProducerEndpoint::new("a", 4150)
  let b = @moon-nsq.ProducerEndpoint::new("b", 4150)
  let pool = @moon-nsq.ConnectionPool::new([a])
  let old = pool.lease(0L)
  pool.release(old)
  pool.refresh([b])
  let fresh = pool.lease(1L)
  assert_eq(fresh.generation(), 1)
  assert_eq(fresh.endpoint().address(), "b:4150")
}
