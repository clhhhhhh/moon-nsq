///|
test "connection options accept documented defaults" {
  let options = @moon-nsq.ConnectionOptions::new()
  assert_eq(options.client_id, "moon-nsq")
  assert_eq(options.heartbeat_interval, 30_000)
  assert_false(options.tls_v1)
}

///|
test "connection options reject invalid or inconsistent settings" {
  let invalid = [
    () => @moon-nsq.ConnectionOptions::new(client_id=""),
    () => @moon-nsq.ConnectionOptions::new(heartbeat_interval=999),
    () => @moon-nsq.ConnectionOptions::new(sample_rate=101),
    () => @moon-nsq.ConnectionOptions::new(tls_v1=true),
  ]
  for make in invalid {
    try make() catch {
      _ => ()
    } noraise {
      _ => fail("accepted invalid connection options")
    }
  }
}

///|
test "consumer options reject unusable flow control" {
  for
    make in [
      () => @moon-nsq.ConsumerOptions::new(max_in_flight=0),
      () => @moon-nsq.ConsumerOptions::new(requeue_delay=-1),
      () => @moon-nsq.ConsumerOptions::new(max_attempts=0),
    ] {
    try make() catch {
      _ => ()
    } noraise {
      _ => fail("accepted invalid consumer options")
    }
  }
}

///|
test "backoff grows without overflowing its cap" {
  let backoff = @moon-nsq.BackoffOptions::new(initial_delay=100, max_delay=750)
  assert_eq(backoff.delay_for(0), 100)
  assert_eq(backoff.delay_for(1), 200)
  assert_eq(backoff.delay_for(2), 400)
  assert_eq(backoff.delay_for(3), 750)
  assert_eq(backoff.delay_for(100), 750)
}
