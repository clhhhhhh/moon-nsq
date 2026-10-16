///|
test "identify JSON uses NSQ field names and escapes input" {
  let options = ConnectionOptions::new(
    client_id="worker\"east",
    hostname="host\\zone",
    heartbeat_interval=12_000,
    output_buffer_size=0,
    sample_rate=25,
    feature_negotiation=true,
  )
  let text = @utf8.decode_lossy(identify_body(options))
  assert_true(text.contains("\"client_id\":\"worker\\\"east\""))
  assert_true(text.contains("\"hostname\":\"host\\\\zone\""))
  assert_true(text.contains("\"msg_timeout\":60000"))
  assert_true(text.contains("\"feature_negotiation\":true"))
}
