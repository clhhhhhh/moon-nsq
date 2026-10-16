///|
test "admin operations expose stable labels" {
  let create = @moon-nsq.create_topic_operation("orders")
  let pause = @moon-nsq.pause_operation("orders")
  let channel = @moon-nsq.create_channel_operation("orders", "workers")
  assert_eq(create.http_method(), "POST")
  assert_true(create.is_mutating())
  assert_eq(create.label(), "topic.create")
  assert_eq(pause.label(), "topic.pause")
  assert_eq(channel.label(), "channel.create")
}
