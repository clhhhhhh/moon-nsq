///|
/// Incrementally assembles complete NSQ V2 frames from arbitrary TCP chunks.
pub struct FrameStream {
  mut buffered : Bytes
}

///|
pub fn FrameStream::new() -> FrameStream {
  { buffered: b"", }
}

///|
/// Number of bytes retained while waiting for a complete frame.
pub fn FrameStream::buffered_bytes(self : FrameStream) -> Int {
  self.buffered.length()
}

///|
/// Appends bytes from one transport read without attempting to decode them.
pub fn FrameStream::push(
  self : FrameStream,
  chunk : Bytes,
) -> Unit raise ProtocolError {
  if self.buffered.length() > max_frame_size + 4 - chunk.length() {
    raise InvalidFrameLength(self.buffered.length() + chunk.length())
  }
  let output = @buffer.Buffer(size_hint=self.buffered.length() + chunk.length())
  output.write_bytes(self.buffered)
  output.write_bytes(chunk)
  self.buffered = output.to_bytes()
}

///|
/// Removes and returns one complete frame, or `None` when more bytes are needed.
pub fn FrameStream::next(self : FrameStream) -> Frame? raise ProtocolError {
  if self.buffered.length() < 4 {
    return None
  }
  let size = decode_u32(self.buffered, 0)
  if size < 4 || size > max_frame_size {
    raise InvalidFrameLength(size)
  }
  let total = size + 4
  if self.buffered.length() < total {
    return None
  }
  let frame = decode_frame(self.buffered[:total].to_owned())
  self.buffered = self.buffered[total:].to_owned()
  Some(frame)
}

///|
/// Drops all retained partial bytes.
pub fn FrameStream::clear(self : FrameStream) -> Unit {
  self.buffered = b""
}
