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
      assert_eq(peer.read_exactly(11), b"PUB events\n")
      let payload_length = decode_u32(peer.read_exactly(4), 0)
      assert_eq(peer.read_exactly(payload_length), b"\x00ok")
      peer.write(encode_frame(0, b"OK"))
    }
    let connection = connect("127.0.0.1", port)
    defer connection.close()
    connection.identify()
    connection.publish("events", b"\x00ok")
  }
  server.close()
}
