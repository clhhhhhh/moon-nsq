///|
/// A delivered NSQ message after removal of the V2 frame envelope.
pub struct Message {
  timestamp : Int64
  attempts : Int
  id : Bytes
  body : Bytes
} derive(Debug)

///|
pub extend Message with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Decodes the timestamp, retry count, identifier, and body in an NSQ message.
pub fn decode_message(data : Bytes) -> Message raise ProtocolError {
  if data.length() < 26 {
    raise TruncatedMessage(data.length())
  }
  let timestamp = data.unsafe_read_uint64_be(0).reinterpret_as_int64()
  let attempts = (data[8].to_int() << 8) | data[9].to_int()
  {
    timestamp,
    attempts,
    id: data[10:26].to_owned(),
    body: data[26:].to_owned(),
  }
}
