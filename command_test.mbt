///|
test "encodes publish and subscription commands" {
  assert_eq(
    @moon-nsq.publish_command("orders.created", b"\x00body"),
    b"PUB orders.created\n\x00\x00\x00\x05\x00body",
  )
  assert_eq(
    @moon-nsq.subscribe_command("orders.created", "email-worker"),
    b"SUB orders.created email-worker\n",
  )
  assert_eq(@moon-nsq.ready_command(0), b"RDY 0\n")
  assert_eq(
    @moon-nsq.message_command("FIN", b"abcdefghijklmnop"),
    b"FIN abcdefghijklmnop\n",
  )
}

///|
test "encodes deferred and multi-publish payloads" {
  assert_eq(
    @moon-nsq.deferred_publish_command("jobs", 125, b"x"),
    b"DPUB jobs 125\n\x00\x00\x00\x01x",
  )
  assert_eq(
    @moon-nsq.multi_publish_command("jobs", [b"a", b"\x00b"]),
    b"MPUB jobs\n\x00\x00\x00\x0f\x00\x00\x00\x02\x00\x00\x00\x01a\x00\x00\x00\x02\x00b",
  )
}

///|
test "encodes control and disposition commands" {
  let id = b"abcdefghijklmnop"
  assert_eq(@moon-nsq.nop_command(), b"NOP\n")
  assert_eq(@moon-nsq.close_command(), b"CLS\n")
  assert_eq(@moon-nsq.touch_command(id), b"TOUCH abcdefghijklmnop\n")
  assert_eq(@moon-nsq.requeue_command(id, 250), b"REQ abcdefghijklmnop 250\n")
}

///|
test "rejects invalid multi publish and delay inputs" {
  let invalid = [
    () => @moon-nsq.multi_publish_command("jobs", []),
    () => @moon-nsq.deferred_publish_command("jobs", -1, b"x"),
    () => @moon-nsq.requeue_command(b"short", 0),
  ]
  for make in invalid {
    try make() catch {
      _ => ()
    } noraise {
      _ => fail("accepted invalid command")
    }
  }
}

///|
test "rejects command injection and invalid ready counts" {
  for name in ["", "topic\nRDY 1", "two words"] {
    try @moon-nsq.subscribe_command(name, "worker") catch {
      _ => ()
    } noraise {
      _ => fail("accepted invalid name")
    }
  }
  try @moon-nsq.ready_command(-1) catch {
    _ => ()
  } noraise {
    _ => fail("accepted negative RDY count")
  }
}
