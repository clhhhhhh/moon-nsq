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

///|
test "foreign and stale leases cannot corrupt pool accounting" {
  let endpoint = @moon-nsq.ProducerEndpoint::new("a", 4150)
  let first = @moon-nsq.ConnectionPool::new([endpoint])
  let second = @moon-nsq.ConnectionPool::new([endpoint])
  let lease = first.lease(0L)
  let other = second.lease(0L)
  second.release(lease)
  assert_eq(second.active(), 1)
  assert_true(!lease.is_released())
  assert_true(!second.mark_failure(lease, 0L))
  assert_eq(second.stats().failures(), 0)
  first.refresh([endpoint])
  assert_true(!first.mark_failure(lease, 1L))
  assert_true(!first.mark_success(lease))
  first.release(lease)
  assert_eq(first.active(), 0)
  second.release(other)
  assert_true(!second.mark_success(other))
}

///|
test "invalid discovery refresh preserves pool state" {
  let endpoint = @moon-nsq.ProducerEndpoint::new("a", 4150)
  let pool = @moon-nsq.ConnectionPool::new([endpoint])
  try pool.refresh([endpoint, endpoint]) catch {
    _ => ()
  } noraise {
    _ => fail("accepted duplicate endpoints")
  }
  let lease = pool.lease(0L)
  assert_eq(lease.generation(), 0)
  assert_eq(lease.endpoint().address(), "a:4150")
  pool.release(lease)
}
