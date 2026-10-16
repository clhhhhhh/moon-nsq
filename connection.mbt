///|
/// A single NSQ TCP connection. Concurrent reads on one connection are unsupported.
pub struct Connection {
  priv tcp : @socket.Tcp
}

///|
struct IdentifyPayload {
  client_id : String
  hostname : String
  heartbeat_interval : Int
  output_buffer_size : Int
  output_buffer_timeout : Int
  msg_timeout : Int
  sample_rate : Int
  feature_negotiation : Bool
} derive(ToJson)

///|
pub extend IdentifyPayload with ToJson::{to_json}

///|
fn identify_body(options : ConnectionOptions) -> Bytes {
  let payload = {
    client_id: options.client_id,
    hostname: options.hostname,
    heartbeat_interval: options.heartbeat_interval,
    output_buffer_size: options.output_buffer_size,
    output_buffer_timeout: options.output_buffer_timeout,
    msg_timeout: options.message_timeout,
    sample_rate: options.sample_rate,
    feature_negotiation: options.feature_negotiation,
  }
  @utf8.encode(@json.to_json(payload).stringify())
}

///|
async fn read_frame(tcp : @socket.Tcp) -> Frame {
  let header = tcp.read_exactly(4)
  let size = decode_u32(header, 0)
  if size < 4 || size > max_frame_size {
    raise InvalidFrameLength(size)
  }
  let packet = tcp.read_exactly(size)
  let output = @buffer.Buffer(size_hint=size + 4)
  output.write_bytes(header)
  output.write_bytes(packet)
  decode_frame(output.to_bytes())
}

///|
async fn next_frame(tcp : @socket.Tcp) -> Frame {
  while true {
    match read_frame(tcp) {
      Response(body) if body == b"_heartbeat_" => tcp.write(b"NOP\n")
      frame => return frame
    }
  } nobreak {
    raise UnexpectedFrame("unreachable")
  }
}

///|
async fn expect_ok(tcp : @socket.Tcp) -> Unit {
  match next_frame(tcp) {
    Response(body) if body == b"OK" => ()
    Error(body) => raise ServerError(@utf8.decode_lossy(body))
    _ => raise UnexpectedFrame("expected OK response")
  }
}

///|
/// Opens a TCP connection and writes the mandatory NSQ V2 magic preamble.
pub async fn connect(host : String, port : Int) -> Connection {
  @async.with_timeout(30_000, () => {
    let tcp = @socket.Tcp::connect_to_host(host, port~)
    tcp.write(magic_v2)
    { tcp, }
  })
}

///|
pub fn Connection::close(self : Connection) -> Unit {
  self.tcp.close()
}

///|
/// Sends `IDENTIFY` with feature negotiation disabled.
pub async fn Connection::identify(
  self : Connection,
  heartbeat_interval? : Int = 30_000,
) -> Unit {
  let options = ConnectionOptions::new(heartbeat_interval~)
  self.identify_with_options(options)
}

///|
/// Sends all supported `IDENTIFY` settings and waits for the broker response.
pub async fn Connection::identify_with_options(
  self : Connection,
  options : ConnectionOptions,
) -> Unit {
  options.validate()
  if options.tls_v1 {
    raise InvalidOption("TLS IDENTIFY requires the TLS connection API")
  }
  let body = identify_body(options)
  self.tcp.write(b"IDENTIFY\n")
  self.tcp.write(encode_u32(body.length()))
  self.tcp.write(body)
  expect_ok(self.tcp)
}

///|
/// Publishes one binary message and waits for the broker acknowledgement.
pub async fn Connection::publish(
  self : Connection,
  topic : String,
  body : Bytes,
) -> Unit {
  self.tcp.write(publish_command(topic, body))
  expect_ok(self.tcp)
}

///|
/// Publishes a message after the requested broker-side delay.
pub async fn Connection::publish_deferred(
  self : Connection,
  topic : String,
  delay_ms : Int,
  body : Bytes,
) -> Unit {
  self.tcp.write(deferred_publish_command(topic, delay_ms, body))
  expect_ok(self.tcp)
}

///|
/// Sends the current contents of a batch as one `MPUB` request and clears it on success.
pub async fn Connection::publish_batch(
  self : Connection,
  batch : PublishBatch,
) -> Unit {
  let command = batch.command()
  self.tcp.write(command)
  expect_ok(self.tcp)
  batch.clear()
}

///|
/// Writes `NOP`. NSQ sends no response; this does not confirm broker liveness.
pub async fn Connection::ping(self : Connection) -> Unit {
  self.tcp.write(nop_command())
}

///|
/// Subscribes this connection to one topic/channel pair.
pub async fn Connection::subscribe(
  self : Connection,
  topic : String,
  channel : String,
) -> Unit {
  self.tcp.write(subscribe_command(topic, channel))
  expect_ok(self.tcp)
}

///|
/// Changes the number of messages the broker may deliver to this connection.
pub async fn Connection::ready(self : Connection, count : Int) -> Unit {
  self.tcp.write(ready_command(count))
}

///|
/// Waits for the next delivered message, automatically answering heartbeats.
pub async fn Connection::receive(self : Connection) -> Message {
  match next_frame(self.tcp) {
    Message(body) => decode_message(body)
    Error(body) => raise ServerError(@utf8.decode_lossy(body))
    _ => raise UnexpectedFrame("expected message frame")
  }
}

///|
/// Marks a message as processed.
pub async fn Connection::finish(self : Connection, id : Bytes) -> Unit {
  self.tcp.write(message_command("FIN", id))
}

///|
/// Extends the server-side timeout for an in-flight message.
pub async fn Connection::touch(self : Connection, id : Bytes) -> Unit {
  self.tcp.write(touch_command(id))
}

///|
/// Stops new delivery and waits for NSQ's `CLOSE_WAIT` acknowledgement.
pub async fn Connection::close_gracefully(self : Connection) -> Unit {
  self.tcp.write(close_command())
  match next_frame(self.tcp) {
    Response(body) if body == b"CLOSE_WAIT" => ()
    Error(body) => raise ServerError(@utf8.decode_lossy(body))
    _ => raise UnexpectedFrame("expected CLOSE_WAIT response")
  }
}

///|
/// Requeues a message after the requested delay in milliseconds.
pub async fn Connection::requeue(
  self : Connection,
  id : Bytes,
  delay_ms : Int,
) -> Unit {
  self.tcp.write(requeue_command(id, delay_ms))
}
