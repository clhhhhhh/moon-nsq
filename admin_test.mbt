///|
test "admin operation paths are validated and encoded" {
  assert_eq(
    @moon-nsq.AdminClient::new("127.0.0.1").url(
      @moon-nsq.create_topic_operation("orders"),
    ),
    "http://127.0.0.1:4151/topic/create?topic=orders",
  )
  assert_eq(
    @moon-nsq.AdminClient::new("broker", port=5151, base_path="/api").url(
      @moon-nsq.create_channel_operation("orders", "workers"),
    ),
    "http://broker:5151/api/channel/create?topic=orders&channel=workers",
  )
  let client = @moon-nsq.AdminClient::new("broker")
  assert_eq(client.stats_url(), "http://broker:4151/stats?format=json")
  assert_eq(
    client.stats_url(format="text"),
    "http://broker:4151/stats?format=text",
  )
}

///|
test "admin rejects malformed operations and formats" {
  try @moon-nsq.AdminClient::new("bad host") catch {
    _ => ()
  } noraise {
    _ => fail("accepted malformed admin host")
  }
  let client = @moon-nsq.AdminClient::new("broker")
  try client.stats_url(format="xml") catch {
    _ => ()
  } noraise {
    _ => fail("accepted unsupported stats format")
  }
  try @moon-nsq.create_topic_operation("bad topic").path() catch {
    _ => ()
  } noraise {
    _ => fail("accepted malformed topic")
  }
}
