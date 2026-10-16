///|
test "topology plan validates matching unique channels" {
  let topic = @moon-nsq.TopicSpec::new("orders", partitions=3)
  let a = @moon-nsq.ChannelSpec::new("orders", "email")
  let b = @moon-nsq.ChannelSpec::new("orders", "billing")
  let plan = @moon-nsq.TopologyPlan::new(topic, [a, b])
  assert_true(plan.contains_channel("email"))
  assert_false(plan.contains_channel("missing"))
  assert_eq(plan.topic().partitions(), 3)
}

///|
test "topology plan rejects mismatched and duplicate channels" {
  let topic = @moon-nsq.TopicSpec::new("orders")
  let wrong = @moon-nsq.ChannelSpec::new("other", "email")
  try @moon-nsq.TopologyPlan::new(topic, [wrong]) catch {
    _ => ()
  } noraise {
    _ => fail("accepted a mismatched channel")
  }
  let first = @moon-nsq.ChannelSpec::new("orders", "email")
  let second = @moon-nsq.ChannelSpec::new("orders", "email")
  try @moon-nsq.TopologyPlan::new(topic, [first, second]) catch {
    _ => ()
  } noraise {
    _ => fail("accepted duplicate channel")
  }
}
