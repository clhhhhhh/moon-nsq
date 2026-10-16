///|
test "broker set selects endpoints round robin" {
  let a = @moon-nsq.ProducerEndpoint::new("10.0.0.1", 4150)
  let b = @moon-nsq.ProducerEndpoint::new("10.0.0.2", 4150)
  let set = @moon-nsq.BrokerSet::new([a, b])
  assert_eq(set.length(), 2)
  assert_eq(set.next().address(), "10.0.0.1:4150")
  assert_eq(set.next().address(), "10.0.0.2:4150")
  assert_eq(set.next().address(), "10.0.0.1:4150")
}

///|
test "broker set resets after a replacement" {
  let a = @moon-nsq.ProducerEndpoint::new("10.0.0.1", 4150)
  let b = @moon-nsq.ProducerEndpoint::new("10.0.0.2", 4150)
  let set = @moon-nsq.BrokerSet::new([a, b])
  ignore(set.next())
  set.replace([b])
  assert_eq(set.length(), 1)
  assert_eq(set.next().address(), "10.0.0.2:4150")
}

///|
test "broker set rejects empty and duplicate endpoints" {
  let a = @moon-nsq.ProducerEndpoint::new("10.0.0.1", 4150)
  for
    make in [
      () => @moon-nsq.BrokerSet::new([]),
      () => @moon-nsq.BrokerSet::new([a, a]),
    ] {
    try make() catch {
      _ => ()
    } noraise {
      _ => fail("accepted invalid broker set")
    }
  }
}
