///|
/// The disposition chosen after a consumer handler sees one message.
pub enum Disposition {
  Finish
  Requeue(Int)
  Discard
} derive(Debug)

///|
pub extend Disposition with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Creates a successful processing decision.
pub fn finish_disposition() -> Disposition {
  Finish
}

///|
/// Creates a retry decision with an application-selected delay.
pub fn requeue_disposition(delay_ms : Int) -> Disposition raise ProtocolError {
  if delay_ms < 0 || delay_ms > 3_600_000 {
    raise InvalidOption("requeue delay must be between 0 and 3600000ms")
  }
  Requeue(delay_ms)
}

///|
/// Creates a permanent discard decision.
pub fn discard_disposition() -> Disposition {
  Discard
}

///|
/// Counters for one consumer session.
pub struct ConsumerStats {
  received : Int
  finished : Int
  requeued : Int
  discarded : Int
  touched : Int
} derive(Debug)

///|
pub extend ConsumerStats with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// A stateful NSQ subscription built on one TCP connection.
pub struct Consumer {
  priv connection : Connection
  topic : String
  channel : String
  options : ConsumerOptions
  mut started : Bool
  mut received : Int
  mut finished : Int
  mut requeued : Int
  mut discarded : Int
  mut touched : Int
}

///|
/// Opens, identifies, and prepares a consumer without starting delivery.
pub async fn Consumer::connect(
  host : String,
  port : Int,
  topic : String,
  channel : String,
  options? : ConsumerOptions = ConsumerOptions::new(),
  connection_options? : ConnectionOptions = ConnectionOptions::new(),
) -> Consumer {
  validate_name(topic)
  validate_name(channel)
  options.validate()
  connection_options.validate()
  let connection = connect(host, port)
  connection.identify_with_options(connection_options)
  {
    connection,
    topic,
    channel,
    options,
    started: false,
    received: 0,
    finished: 0,
    requeued: 0,
    discarded: 0,
    touched: 0,
  }
}

///|
/// Sends `SUB` and the initial `RDY` count exactly once.
pub async fn Consumer::start(self : Consumer) -> Unit {
  if self.started {
    raise InvalidState("consumer has already started")
  }
  self.connection.subscribe(self.topic, self.channel)
  self.connection.ready(self.options.max_in_flight)
  self.started = true
}

///|
/// Pauses delivery without closing the TCP connection.
pub async fn Consumer::pause(self : Consumer) -> Unit {
  if !self.started {
    raise InvalidState("consumer is not started")
  }
  self.connection.ready(0)
}

///|
/// Restores the configured in-flight allowance after a pause.
pub async fn Consumer::continue_delivery(self : Consumer) -> Unit {
  if !self.started {
    raise InvalidState("consumer is not started")
  }
  self.connection.ready(self.options.max_in_flight)
}

///|
/// Reads one message. The caller must settle it through `finish`, `requeue`, or `discard`.
pub async fn Consumer::receive(self : Consumer) -> Message {
  if !self.started {
    raise InvalidState("consumer is not started")
  }
  let message = self.connection.receive()
  self.received += 1
  message
}

///|
/// Acknowledges a message as processed successfully.
pub async fn Consumer::finish(self : Consumer, message : Message) -> Unit {
  self.connection.finish(message.id)
  self.finished += 1
}

///|
/// Requeues a message unless the configured retry ceiling was reached.
pub async fn Consumer::requeue(self : Consumer, message : Message) -> Unit {
  if message.attempts >= self.options.max_attempts {
    self.connection.finish(message.id)
    self.discarded += 1
  } else {
    self.connection.requeue(message.id, self.options.requeue_delay)
    self.requeued += 1
  }
}

///|
/// Permanently acknowledges a message that the application intentionally discards.
pub async fn Consumer::discard(self : Consumer, message : Message) -> Unit {
  self.connection.finish(message.id)
  self.discarded += 1
}

///|
/// Extends a long-running message's timeout.
pub async fn Consumer::touch(self : Consumer, message : Message) -> Unit {
  self.connection.touch(message.id)
  self.touched += 1
}

///|
/// Applies one handler decision, including automatic discard after too many attempts.
pub async fn Consumer::process_one(
  self : Consumer,
  handler : async (Message) -> Disposition,
) -> Unit {
  let message = self.receive()
  match handler(message) {
    Finish => self.finish(message)
    Requeue(_) if message.attempts >= self.options.max_attempts =>
      self.discard(message)
    Requeue(delay) => {
      self.connection.requeue(message.id, delay)
      self.requeued += 1
    }
    Discard => self.discard(message)
  }
}

///|
/// Returns a snapshot of counters collected by this consumer session.
pub fn Consumer::stats(self : Consumer) -> ConsumerStats {
  {
    received: self.received,
    finished: self.finished,
    requeued: self.requeued,
    discarded: self.discarded,
    touched: self.touched,
  }
}

///|
/// Stops delivery, waits for `CLOSE_WAIT`, then closes the underlying socket.
pub async fn Consumer::close(self : Consumer) -> Unit {
  if self.started {
    self.connection.close_gracefully()
    self.started = false
  }
  self.connection.close()
}
