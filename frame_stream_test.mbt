///|
test "frame stream waits for a fragmented header and payload" {
  let stream = @moon-nsq.FrameStream::new()
  let encoded = @moon-nsq.encode_frame(0, b"OK")
  stream.push(encoded[:2].to_owned())
  assert_true(stream.next() is None)
  stream.push(encoded[2:7].to_owned())
  assert_true(stream.next() is None)
  stream.push(encoded[7:].to_owned())
  match stream.next() {
    Some(@moon-nsq.Response(body)) => assert_eq(body, b"OK")
    _ => fail("did not decode completed response")
  }
  assert_eq(stream.buffered_bytes(), 0)
}

///|
test "frame stream preserves a second coalesced frame" {
  let stream = @moon-nsq.FrameStream::new()
  let first = @moon-nsq.encode_frame(0, b"OK")
  let second = @moon-nsq.encode_frame(2, b"message")
  stream.push(Bytes::from_array(first.to_array() + second.to_array()))
  match stream.next() {
    Some(@moon-nsq.Response(body)) => assert_eq(body, b"OK")
    _ => fail("missing first frame")
  }
  match stream.next() {
    Some(@moon-nsq.Message(body)) => assert_eq(body, b"message")
    _ => fail("missing second frame")
  }
}

///|
test "frame stream rejects an invalid length before buffering more" {
  let stream = @moon-nsq.FrameStream::new()
  stream.push(b"\x00\x00\x00\x03")
  try stream.next() catch {
    _ => ()
  } noraise {
    _ => fail("accepted an invalid frame length")
  }
}

///|
test "frame stream can discard a partial frame" {
  let stream = @moon-nsq.FrameStream::new()
  stream.push(b"\x00\x00\x00")
  assert_eq(stream.buffered_bytes(), 3)
  stream.clear()
  assert_true(stream.next() is None)
}
