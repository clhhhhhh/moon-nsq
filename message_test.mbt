///|
test "decodes binary NSQ message metadata" {
  let frame = b"\x00\x00\x00\x00\x07[\xcd\x15\x00\x02abcdefghijklmnophello\x00\xff"
  let message = @moon-nsq.decode_message(frame)
  assert_eq(message.timestamp, 123_456_789)
  assert_eq(message.attempts, 2)
  assert_eq(message.id, b"abcdefghijklmnop")
  assert_eq(message.body, b"hello\x00\xff")
}

///|
test "rejects truncated NSQ messages" {
  try @moon-nsq.decode_message(b"short") catch {
    _ => ()
  } noraise {
    _ => fail("accepted truncated message")
  }
}
