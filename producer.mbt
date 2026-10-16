///|
/// Counters for a producer connection.
pub struct ProducerStats {
  published : Int
  deferred : Int
  batches : Int
  batch_messages : Int
} derive(Debug)

///|
pub extend ProducerStats with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// A topic-bound producer over one already identified NSQ connection.
pub struct Producer {
  priv connection : Connection
  topic : String
  mut published : Int
  mut deferred : Int
  mut batches : Int
  mut batch_messages : Int
}

///|
/// Opens and identifies a topic-bound producer.
pub async fn Producer::connect(
  host : String,
  port : Int,
  topic : String,
  options? : ConnectionOptions = ConnectionOptions::new(),
) -> Producer {
  validate_name(topic)
  options.validate()
  let connection = connect(host, port)
  connection.identify_with_options(options)
  {
    connection,
    topic,
    published: 0,
    deferred: 0,
    batches: 0,
    batch_messages: 0,
  }
}

///|
/// Publishes one binary message to the producer's configured topic.
pub async fn Producer::publish(self : Producer, body : Bytes) -> Unit {
  self.connection.publish(self.topic, body)
  self.published += 1
}

///|
/// Publishes one binary message after a broker-side delay.
pub async fn Producer::publish_deferred(
  self : Producer,
  delay_ms : Int,
  body : Bytes,
) -> Unit {
  self.connection.publish_deferred(self.topic, delay_ms, body)
  self.deferred += 1
}

///|
/// Creates a bounded batch that targets this producer's topic.
pub fn Producer::new_batch(
  self : Producer,
  max_messages? : Int = 100,
  max_bytes? : Int = 1_048_000,
) -> PublishBatch raise ProtocolError {
  PublishBatch::new(self.topic, max_messages~, max_bytes~)
}

///|
/// Sends all queued messages in a batch and records the total count.
pub async fn Producer::publish_batch(
  self : Producer,
  batch : PublishBatch,
) -> Unit {
  let count = batch.length()
  self.connection.publish_batch(batch)
  self.batches += 1
  self.batch_messages += count
}

///|
/// Sends a one-way `NOP`; no acknowledgement is provided by NSQ.
pub async fn Producer::ping(self : Producer) -> Unit {
  self.connection.ping()
}

///|
pub fn Producer::stats(self : Producer) -> ProducerStats {
  {
    published: self.published,
    deferred: self.deferred,
    batches: self.batches,
    batch_messages: self.batch_messages,
  }
}

///|
/// Closes the underlying connection immediately.
pub fn Producer::close(self : Producer) -> Unit {
  self.connection.close()
}
