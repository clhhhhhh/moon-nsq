///|
/// Settings sent by `IDENTIFY` when a connection is opened.
pub struct ConnectionOptions {
  client_id : String
  hostname : String
  heartbeat_interval : Int
  output_buffer_size : Int
  output_buffer_timeout : Int
  message_timeout : Int
  sample_rate : Int
  tls_v1 : Bool
  feature_negotiation : Bool
} derive(Debug)

///|
pub extend ConnectionOptions with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Creates conservative settings compatible with NSQ 1.x brokers.
pub fn ConnectionOptions::new(
  client_id? : String = "moon-nsq",
  hostname? : String = "moonbit",
  heartbeat_interval? : Int = 30_000,
  output_buffer_size? : Int = 16_384,
  output_buffer_timeout? : Int = 250,
  message_timeout? : Int = 60_000,
  sample_rate? : Int = 0,
  tls_v1? : Bool = false,
  feature_negotiation? : Bool = false,
) -> ConnectionOptions raise ProtocolError {
  let options = {
    client_id,
    hostname,
    heartbeat_interval,
    output_buffer_size,
    output_buffer_timeout,
    message_timeout,
    sample_rate,
    tls_v1,
    feature_negotiation,
  }
  options.validate()
  options
}

///|
/// Checks ranges before any bytes are sent to a broker.
pub fn ConnectionOptions::validate(
  self : ConnectionOptions,
) -> Unit raise ProtocolError {
  if self.client_id.length() == 0 || self.client_id.length() > 64 {
    raise InvalidOption("client_id must contain 1 to 64 characters")
  }
  if self.hostname.length() == 0 || self.hostname.length() > 255 {
    raise InvalidOption("hostname must contain 1 to 255 characters")
  }
  if self.heartbeat_interval < 1_000 || self.heartbeat_interval > 3_600_000 {
    raise InvalidOption("heartbeat_interval must be between 1000 and 3600000ms")
  }
  if self.output_buffer_size < 0 || self.output_buffer_size > 65_536 {
    raise InvalidOption("output_buffer_size must be between 0 and 65536")
  }
  if self.output_buffer_timeout < 1 || self.output_buffer_timeout > 60_000 {
    raise InvalidOption("output_buffer_timeout must be between 1 and 60000ms")
  }
  if self.message_timeout < 1_000 || self.message_timeout > 3_600_000 {
    raise InvalidOption("message_timeout must be between 1000 and 3600000ms")
  }
  if self.sample_rate < 0 || self.sample_rate > 100 {
    raise InvalidOption("sample_rate must be between 0 and 100")
  }
  if self.tls_v1 && !self.feature_negotiation {
    raise InvalidOption("TLS requires feature negotiation")
  }
}

///|
/// Consumer-local settings that do not alter broker topology.
pub struct ConsumerOptions {
  max_in_flight : Int
  requeue_delay : Int
  max_attempts : Int
  touch_interval : Int
} derive(Debug)

///|
pub extend ConsumerOptions with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn ConsumerOptions::new(
  max_in_flight? : Int = 1,
  requeue_delay? : Int = 0,
  max_attempts? : Int = 5,
  touch_interval? : Int = 30_000,
) -> ConsumerOptions raise ProtocolError {
  let options = { max_in_flight, requeue_delay, max_attempts, touch_interval, }
  options.validate()
  options
}

///|
pub fn ConsumerOptions::validate(
  self : ConsumerOptions,
) -> Unit raise ProtocolError {
  if self.max_in_flight < 1 || self.max_in_flight > 2_500 {
    raise InvalidOption("max_in_flight must be between 1 and 2500")
  }
  if self.requeue_delay < 0 || self.requeue_delay > 3_600_000 {
    raise InvalidOption("requeue_delay must be between 0 and 3600000ms")
  }
  if self.max_attempts < 1 || self.max_attempts > 65_535 {
    raise InvalidOption("max_attempts must be between 1 and 65535")
  }
  if self.touch_interval < 1_000 || self.touch_interval > 3_600_000 {
    raise InvalidOption("touch_interval must be between 1000 and 3600000ms")
  }
}

///|
/// A bounded exponential delay policy used after disconnected sessions.
pub struct BackoffOptions {
  initial_delay : Int
  max_delay : Int
  multiplier : Int
} derive(Debug)

///|
pub extend BackoffOptions with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn BackoffOptions::new(
  initial_delay? : Int = 100,
  max_delay? : Int = 30_000,
  multiplier? : Int = 2,
) -> BackoffOptions raise ProtocolError {
  let options = { initial_delay, max_delay, multiplier, }
  if options.initial_delay < 1 || options.max_delay < options.initial_delay {
    raise InvalidOption("backoff delays must be positive and ordered")
  }
  if options.multiplier < 1 || options.multiplier > 16 {
    raise InvalidOption("backoff multiplier must be between 1 and 16")
  }
  options
}

///|
/// Returns the capped delay for a zero-based reconnect attempt.
pub fn BackoffOptions::delay_for(self : BackoffOptions, attempt : Int) -> Int {
  if attempt <= 0 {
    return self.initial_delay
  }
  let mut delay = self.initial_delay
  for _ in 0..<attempt {
    if delay >= self.max_delay {
      return self.max_delay
    }
    if delay > self.max_delay / self.multiplier {
      return self.max_delay
    }
    delay = delay * self.multiplier
  }
  delay
}
