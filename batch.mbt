///|
/// Result of attempting to add a message to a bounded publish batch.
pub enum BatchPush {
  Added
  Full
  TooLarge
} derive(Debug, Eq)

///|
pub extend BatchPush with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BatchPush with Eq::{equal, not_equal}

///|
/// A reusable, bounded collection that produces one NSQ `MPUB` command.
pub struct PublishBatch {
  topic : String
  max_messages : Int
  max_bytes : Int
  mut bodies : Array[Bytes]
  mut payload_bytes : Int
} derive(Debug)

///|
pub extend PublishBatch with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn PublishBatch::new(
  topic : String,
  max_messages? : Int = 100,
  max_bytes? : Int = 1_048_000,
) -> PublishBatch raise ProtocolError {
  validate_name(topic)
  if max_messages < 1 || max_messages > 10_000 {
    raise InvalidOption("batch max_messages must be between 1 and 10000")
  }
  if max_bytes < 8 || max_bytes > max_frame_size - 4 {
    raise InvalidOption("batch max_bytes must fit in one NSQ frame")
  }
  { topic, max_messages, max_bytes, bodies: [], payload_bytes: 4, }
}

///|
/// Number of queued bodies, excluding the MPUB count prefix.
pub fn PublishBatch::length(self : PublishBatch) -> Int {
  self.bodies.length()
}

///|
/// Total bytes that the MPUB payload would consume.
pub fn PublishBatch::encoded_size(self : PublishBatch) -> Int {
  self.payload_bytes
}

///|
pub fn PublishBatch::is_empty(self : PublishBatch) -> Bool {
  self.bodies.length() == 0
}

///|
/// Attempts to append one body without exceeding either configured bound.
pub fn PublishBatch::push(self : PublishBatch, body : Bytes) -> BatchPush {
  let required = body.length() + 4
  if required + 4 > self.max_bytes || body.length() > max_frame_size - 8 {
    return TooLarge
  }
  if self.bodies.length() >= self.max_messages ||
    self.payload_bytes > self.max_bytes - required {
    return Full
  }
  self.bodies.push(body)
  self.payload_bytes += required
  Added
}

///|
/// Returns the binary `MPUB` command without changing the batch.
pub fn PublishBatch::command(self : PublishBatch) -> Bytes raise ProtocolError {
  if self.is_empty() {
    raise InvalidState("cannot flush an empty publish batch")
  }
  multi_publish_command(self.topic, self.bodies)
}

///|
/// Takes the current command and resets the batch for reuse.
pub fn PublishBatch::take_command(
  self : PublishBatch,
) -> Bytes raise ProtocolError {
  let command = self.command()
  self.bodies = []
  self.payload_bytes = 4
  command
}

///|
/// Empties a batch without allocating a command.
pub fn PublishBatch::clear(self : PublishBatch) -> Unit {
  self.bodies = []
  self.payload_bytes = 4
}
