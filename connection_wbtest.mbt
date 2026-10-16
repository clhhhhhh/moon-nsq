///|
async test "connection writes V2 identify and answers heartbeat" {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  let port = server.addr.port()
  @async.with_task_group() <| group => {
    group.spawn_bg() <| () => {
      let (peer, _) = server.accept()
      defer peer.close()
      assert_eq(peer.read_exactly(4), magic_v2)
      assert_eq(peer.read_exactly(9), b"IDENTIFY\n")
      let body_length = decode_u32(peer.read_exactly(4), 0)
      let identify_body = peer.read_exactly(body_length)
      assert_true(
        @utf8.decode_lossy(identify_body).contains("heartbeat_interval"),
      )
      peer.write(encode_frame(0, b"_heartbeat_"))
      assert_eq(peer.read_exactly(4), b"NOP\n")
      peer.write(encode_frame(0, b"OK"))
      // NOP has no response. The subsequent publish must still complete.
      assert_eq(peer.read_exactly(4), b"NOP\n")
      assert_eq(peer.read_exactly(11), b"PUB events\n")
      let payload_length = decode_u32(peer.read_exactly(4), 0)
      assert_eq(peer.read_exactly(payload_length), b"\x00ok")
      peer.write(encode_frame(0, b"OK"))
    }
    let connection = connect("127.0.0.1", port)
    defer connection.close()
    connection.identify()
    connection.ping()
    connection.publish("events", b"\x00ok")
  }
  server.close()
}

///|
async test "rejected MPUB preserves queued messages" {
  @async.with_timeout(5_000, () => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    @async.with_task_group() <| group => {
      group.spawn_bg() <| () => {
        let (peer, _) = server.accept()
        defer peer.close()
        assert_eq(peer.read_exactly(4), magic_v2)
        assert_eq(peer.read_exactly(12), b"MPUB events\n")
        let length = decode_u32(peer.read_exactly(4), 0)
        ignore(peer.read_exactly(length))
        peer.write(encode_frame(1, b"E_MPUB_FAILED"))
      }
      let connection = connect("127.0.0.1", server.addr.port())
      defer connection.close()
      let batch = PublishBatch::new("events")
      ignore(batch.push(b"keep me"))
      try connection.publish_batch(batch) catch {
        ServerError(_) => ()
        other => raise other
      } noraise {
        _ => fail("expected broker rejection")
      }
      assert_eq(batch.length(), 1)
    }
  })
}
