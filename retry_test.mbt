///|
test "retry policy caps exponential delay and dead letters" {
  let policy = @moon-nsq.RetryPolicy::new(
    max_attempts=3,
    initial_delay=100,
    max_delay=500,
    multiplier=2,
  )
  assert_eq(policy.delay_for(1), 100)
  assert_eq(policy.delay_for(2), 200)
  assert_eq(policy.delay_for(4), 500)
  let message = @moon-nsq.decode_message(
    b"\x00\x00\x00\x00\x00\x00\x00\x01\x00\x02abcdefghijklmnopdata",
  )
  match policy.decide(message, @moon-nsq.attempts_exceeded(), 0) {
    @moon-nsq.Retry(delay) => assert_eq(delay, 400)
    _ => fail("attempt two should be retried")
  }
  let exhausted = @moon-nsq.decode_message(
    b"\x00\x00\x00\x00\x00\x00\x00\x01\x00\x03abcdefghijklmnopdata",
  )
  match policy.decide(exhausted, @moon-nsq.attempts_exceeded(), 0) {
    @moon-nsq.DeadLetter(@moon-nsq.AttemptsExceeded) => ()
    _ => fail("attempt ceiling should dead letter")
  }
}

///|
test "retry jitter stays within configured bounds" {
  let policy = @moon-nsq.RetryPolicy::new(
    initial_delay=100,
    max_delay=200,
    jitter_window=20,
  )
  for seed in -100..<100 {
    let delay = policy.delay_with_seed(1, seed)
    assert_true(delay >= 80 && delay <= 120)
  }
}

///|
test "dead letter stats record outcomes" {
  let stats = @moon-nsq.DeadLetterStats::new()
  stats.record_sent(@moon-nsq.handler_rejected())
  stats.record_failure()
  assert_eq(stats.sent(), 1)
  assert_eq(stats.failed(), 1)
}
