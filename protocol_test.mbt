///|
test "encodes and decodes all NSQ V2 frame kinds" {
  let cases = [(0, b"OK"), (1, b"E_BAD_TOPIC"), (2, b"payload\x00\xff")]
  for (kind, body) in cases {
    match @moon-nsq.decode_frame(@moon-nsq.encode_frame(kind, body)) {
      @moon-nsq.Response(actual) => {
        assert_eq(kind, 0)
        assert_eq(actual, body)
      }
      @moon-nsq.Error(actual) => {
        assert_eq(kind, 1)
        assert_eq(actual, body)
      }
      @moon-nsq.Message(actual) => {
        assert_eq(kind, 2)
        assert_eq(actual, body)
      }
    }
  }
}

///|
test "uses unsigned big-endian lengths" {
  for value in [0, 4, 255, 256, 65_535, @moon-nsq.max_frame_size] {
    assert_eq(@moon-nsq.decode_u32(@moon-nsq.encode_u32(value), 0), value)
  }
}

///|
test "rejects malformed frames" {
  let invalid = [b"", b"\x00\x00\x00\x03", b"\x00\x10\x00\x01"]
  for bytes in invalid {
    try @moon-nsq.decode_frame(bytes) catch {
      _ => ()
    } noraise {
      _ => fail("accepted a malformed NSQ frame")
    }
  }
}
