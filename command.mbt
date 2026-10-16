///|
/// The fixed four-byte preamble required before every NSQ TCP session.
pub let magic_v2 : Bytes = b"  V2"

///|
fn valid_name(name : String) -> Bool {
  if name.length() == 0 || name.length() > 64 {
    return false
  }
  for char in name {
    if !(char.is_ascii_alphabetic() ||
      char.is_ascii_digit() ||
      char == '.' ||
      char == '_' ||
      char == '-' ||
      char == '#') {
      return false
    }
  }
  true
}

///|
/// Validates the topic and channel grammar used by NSQ command lines.
pub fn validate_name(name : String) -> Unit raise ProtocolError {
  if !valid_name(name) {
    raise InvalidCommand("invalid NSQ topic or channel: \{name}")
  }
}

///|
fn command_with_body(command : String, body : Bytes) -> Bytes {
  let command = @utf8.encode(command + "\n")
  let output = @buffer.Buffer(size_hint=command.length() + body.length() + 4)
  output.write_bytes(command)
  output.write_bytes(encode_u32(body.length()))
  output.write_bytes(body)
  output.to_bytes()
}

///|
/// Encodes `PUB topic`, including the payload length prefix.
pub fn publish_command(
  topic : String,
  body : Bytes,
) -> Bytes raise ProtocolError {
  validate_name(topic)
  command_with_body("PUB \{topic}", body)
}

///|
/// Encodes `DPUB topic delay`, requesting delayed delivery in milliseconds.
pub fn deferred_publish_command(
  topic : String,
  delay_ms : Int,
  body : Bytes,
) -> Bytes raise ProtocolError {
  validate_name(topic)
  if delay_ms < 0 || delay_ms > 3_600_000 {
    raise InvalidCommand("DPUB delay must be between 0 and 3600000ms")
  }
  command_with_body("DPUB \{topic} \{delay_ms}", body)
}

///|
/// Encodes `MPUB topic` with a count-prefixed collection of binary bodies.
pub fn multi_publish_command(
  topic : String,
  bodies : Array[Bytes],
) -> Bytes raise ProtocolError {
  validate_name(topic)
  if bodies.length() == 0 {
    raise InvalidCommand("MPUB requires at least one message")
  }
  let payload = @buffer.Buffer(size_hint=4)
  payload.write_bytes(encode_u32(bodies.length()))
  for body in bodies {
    if body.length() > max_frame_size - 8 {
      raise InvalidFrameLength(body.length())
    }
    payload.write_bytes(encode_u32(body.length()))
    payload.write_bytes(body)
  }
  if payload.length() > max_frame_size - 4 {
    raise InvalidFrameLength(payload.length() + 4)
  }
  command_with_body("MPUB \{topic}", payload.to_bytes())
}

///|
/// Encodes `SUB topic channel`.
pub fn subscribe_command(
  topic : String,
  channel : String,
) -> Bytes raise ProtocolError {
  validate_name(topic)
  validate_name(channel)
  @utf8.encode("SUB \{topic} \{channel}\n")
}

///|
/// Encodes a bounded `RDY` command. Zero pauses delivery.
pub fn ready_command(count : Int) -> Bytes raise ProtocolError {
  if count < 0 || count > 2_500 {
    raise InvalidCommand("RDY count must be between 0 and 2500")
  }
  @utf8.encode("RDY \{count}\n")
}

///|
/// Encodes `NOP`, useful for testing a TCP session without creating a topic.
pub fn nop_command() -> Bytes {
  b"NOP\n"
}

///|
/// Encodes `CLS`, asking a consumer connection to stop receiving new messages.
pub fn close_command() -> Bytes {
  b"CLS\n"
}

///|
/// Encodes a message disposition command such as `FIN` or `TOUCH`.
pub fn message_command(verb : String, id : Bytes) -> Bytes raise ProtocolError {
  if !(verb == "FIN" || verb == "REQ" || verb == "TOUCH") || id.length() != 16 {
    raise InvalidCommand("invalid message command")
  }
  let output = @buffer.Buffer(size_hint=verb.length() + id.length() + 2)
  output.write_bytes(@utf8.encode(verb + " "))
  output.write_bytes(id)
  output.write_bytes(b"\n")
  output.to_bytes()
}

///|
/// Encodes `TOUCH` to extend a message's configured timeout.
pub fn touch_command(id : Bytes) -> Bytes raise ProtocolError {
  message_command("TOUCH", id)
}

///|
/// Encodes `REQ` without a network connection, for deterministic testing.
pub fn requeue_command(id : Bytes, delay_ms : Int) -> Bytes raise ProtocolError {
  if delay_ms < 0 || delay_ms > 3_600_000 {
    raise InvalidCommand("REQ delay must be between 0 and 3600000ms")
  }
  if id.length() != 16 {
    raise InvalidCommand("NSQ message IDs are exactly 16 bytes")
  }
  let output = @buffer.Buffer(size_hint=id.length() + 16)
  output.write_bytes(b"REQ ")
  output.write_bytes(id)
  output.write_bytes(@utf8.encode(" \{delay_ms}\n"))
  output.to_bytes()
}
