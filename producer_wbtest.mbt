///|
async fn expect_identify(peer : @socket.Tcp) -> Unit {
  assert_eq(peer.read_exactly(4), magic_v2)
  assert_eq(peer.read_exactly(9), b"IDENTIFY\n")
  let size = decode_u32(peer.read_exactly(4), 0)
  let body = @utf8.decode_lossy(peer.read_exactly(size))
  assert_true(body.contains("\"client_id\""))
  peer.write(encode_frame(0, b"OK"))
}

///|
async fn expect_body(peer : @socket.Tcp, line : Bytes, body : Bytes) -> Unit {
  assert_eq(peer.read_exactly(line.length()), line)
  let size = decode_u32(peer.read_exactly(4), 0)
  assert_eq(peer.read_exactly(size), body)
  peer.write(encode_frame(0, b"OK"))
}

///|
async test "producer sends publish deferred batch and ping requests" {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  let port = server.addr.port()
  @async.with_task_group() <| group => {
    group.spawn_bg() <| () => {
      let (peer, _) = server.accept()
      defer peer.close()
      expect_identify(peer)
      expect_body(peer, b"PUB events\n", b"one")
      expect_body(peer, b"DPUB events 30\n", b"two")
      expect_body(
        peer, b"MPUB events\n", b"\x00\x00\x00\x02\x00\x00\x00\x01a\x00\x00\x00\x01b",
      )
      assert_eq(peer.read_exactly(4), b"NOP\n")
      peer.write(encode_frame(0, b"OK"))
    }
    let producer = Producer::connect("127.0.0.1", port, "events")
    defer producer.close()
    producer.publish(b"one")
    producer.publish_deferred(30, b"two")
    let batch = producer.new_batch(max_bytes=100)
    ignore(batch.push(b"a"))
    ignore(batch.push(b"b"))
    producer.publish_batch(batch)
    producer.ping()
    let stats = producer.stats()
    assert_eq(stats.published, 1)
    assert_eq(stats.deferred, 1)
    assert_eq(stats.batches, 1)
    assert_eq(stats.batch_messages, 2)
  }
  server.close()
}
