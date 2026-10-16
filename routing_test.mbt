///|
test "routing skips failed producers until cooldown" {
  let first = @moon-nsq.ProducerEndpoint::new("a", 4150)
  let second = @moon-nsq.ProducerEndpoint::new("b", 4150)
  let table = @moon-nsq.RoutingTable::new([first, second], cooldown_ms=100L)
  assert_eq(table.choose(0L).address(), "a:4150")
  assert_true(table.mark_failure("a:4150", 0L))
  assert_eq(table.choose(1L).address(), "b:4150")
  assert_eq(table.choose(2L).address(), "b:4150")
  assert_eq(table.choose(101L).address(), "a:4150")
  assert_true(table.mark_success("a:4150"))
}

///|
test "routing replacement rejects empty endpoint lists" {
  let endpoint = @moon-nsq.ProducerEndpoint::new("a", 4150)
  let table = @moon-nsq.RoutingTable::new([endpoint])
  try table.replace([]) catch {
    _ => ()
  } noraise {
    _ => fail("accepted empty routing replacement")
  }
}
