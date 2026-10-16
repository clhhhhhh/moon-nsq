///|
/// The NSQ V2 frame header is a 32-bit, big-endian length followed by a type.
pub let max_frame_size : Int = 1_048_576

///|
pub enum Frame {
  Response(Bytes)
  Error(Bytes)
  Message(Bytes)
} derive(Debug, Eq)

///|
pub extend Frame with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Frame with Eq::{equal, not_equal}

///|
pub suberror ProtocolError {
  InvalidFrameLength(Int)
  UnknownFrameType(Int)
  TruncatedFrame(Int)
  InvalidCommand(String)
  TruncatedMessage(Int)
  ServerError(String)
  UnexpectedFrame(String)
  InvalidOption(String)
  InvalidState(String)
} derive(Debug)

///|
pub extend ProtocolError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn decode_u32(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
pub fn encode_u32(value : Int) -> Bytes {
  Bytes::from_array([
    ((value >> 24) & 255).to_byte(),
    ((value >> 16) & 255).to_byte(),
    ((value >> 8) & 255).to_byte(),
    (value & 255).to_byte(),
  ])
}

///|
/// Encodes one NSQ V2 frame. `body` does not include the four-byte type field.
pub fn encode_frame(kind : Int, body : Bytes) -> Bytes raise ProtocolError {
  let size = body.length() + 4
  if size > max_frame_size {
    raise InvalidFrameLength(size)
  }
  let output = @buffer.Buffer(size_hint=size + 4)
  output.write_bytes(encode_u32(size))
  output.write_bytes(encode_u32(kind))
  output.write_bytes(body)
  output.to_bytes()
}

///|
/// Decodes a complete NSQ V2 frame, including its length prefix.
pub fn decode_frame(data : Bytes) -> Frame raise ProtocolError {
  if data.length() < 4 {
    raise TruncatedFrame(4)
  }
  let size = decode_u32(data, 0)
  if size < 4 || size > max_frame_size {
    raise InvalidFrameLength(size)
  }
  if data.length() != size + 4 {
    raise TruncatedFrame(size + 4)
  }
  let kind = decode_u32(data, 4)
  let body = data[8:].to_owned()
  match kind {
    0 => Response(body)
    1 => Error(body)
    2 => Message(body)
    _ => raise UnknownFrameType(kind)
  }
}
