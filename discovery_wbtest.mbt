///|
test "decodes lookupd producer endpoints" {
  let body = "{\"producers\":[{\"broadcast_address\":\"10.0.0.8\",\"tcp_port\":4150,\"http_port\":4151,\"version\":\"1.3.0\"}]}"
  let producers = lookup_response(body)
  assert_eq(producers.length(), 1)
  assert_eq(producers[0].address(), "10.0.0.8:4150")
  assert_eq(producers[0].version, "1.3.0")
}

///|
test "rejects malformed lookupd responses" {
  for
    body in [
      "not json", "{\"producers\":[{\"broadcast_address\":\"\",\"tcp_port\":4150}]}",
      "{\"producers\":[{\"broadcast_address\":\"a\",\"tcp_port\":0}]}",
    ] {
    try lookup_response(body) catch {
      _ => ()
    } noraise {
      _ => fail("accepted invalid lookup response")
    }
  }
}

///|
test "validates lookupd base address" {
  assert_eq(
    Lookupd::new("127.0.0.1", port=4161).base_url,
    "http://127.0.0.1:4161",
  )
  for make in [() => Lookupd::new(""), () => Lookupd::new("host/path")] {
    try make() catch {
      _ => ()
    } noraise {
      _ => fail("accepted invalid lookupd address")
    }
  }
}
