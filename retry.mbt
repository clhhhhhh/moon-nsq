///|
/// Why a consumer stopped retrying a message.
pub enum DeadLetterReason {
  AttemptsExceeded
  HandlerRejected
  InvalidPayload
  Shutdown
} derive(Debug, Eq)

///|
pub extend DeadLetterReason with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DeadLetterReason with Eq::{equal, not_equal}

///|
pub fn attempts_exceeded() -> DeadLetterReason {
  AttemptsExceeded
}

///|
pub fn handler_rejected() -> DeadLetterReason {
  HandlerRejected
}

///|
pub fn invalid_payload() -> DeadLetterReason {
  InvalidPayload
}

///|
pub fn shutdown_reason() -> DeadLetterReason {
  Shutdown
}

///|
/// The action selected by a retry policy.
pub enum RetryAction {
  Retry(Int)
  DeadLetter(DeadLetterReason)
  Finish
} derive(Debug, Eq)

///|
pub extend RetryAction with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RetryAction with Eq::{equal, not_equal}

///|
pub fn finish_action() -> RetryAction {
  Finish
}

///|
/// Retry policy for application handlers that may fail transiently.
pub struct RetryPolicy {
  max_attempts : Int
  initial_delay : Int
  max_delay : Int
  multiplier : Int
  jitter_window : Int
} derive(Debug)

///|
pub extend RetryPolicy with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Creates a bounded exponential policy. Jitter is deterministic when supplied by the caller.
pub fn RetryPolicy::new(
  max_attempts? : Int = 5,
  initial_delay? : Int = 100,
  max_delay? : Int = 60_000,
  multiplier? : Int = 2,
  jitter_window? : Int = 0,
) -> RetryPolicy raise ProtocolError {
  let policy = {
    max_attempts,
    initial_delay,
    max_delay,
    multiplier,
    jitter_window,
  }
  policy.validate()
  policy
}

///|
pub fn RetryPolicy::validate(self : RetryPolicy) -> Unit raise ProtocolError {
  if self.max_attempts < 1 || self.max_attempts > 65_535 {
    raise InvalidOption("max_attempts must be between 1 and 65535")
  }
  if self.initial_delay < 0 || self.max_delay < self.initial_delay {
    raise InvalidOption("retry delays must be ordered and non-negative")
  }
  if self.multiplier < 1 || self.multiplier > 16 {
    raise InvalidOption("retry multiplier must be between 1 and 16")
  }
  if self.jitter_window < 0 || self.jitter_window > self.max_delay {
    raise InvalidOption("jitter window must be within max delay")
  }
}

///|
/// Calculates a capped delay before the next retry.
pub fn RetryPolicy::delay_for(self : RetryPolicy, attempt : Int) -> Int {
  if attempt <= 1 {
    return self.initial_delay
  }
  let mut delay = self.initial_delay
  for _ in 1..<attempt {
    if delay >= self.max_delay {
      return self.max_delay
    }
    if delay > self.max_delay / self.multiplier {
      return self.max_delay
    }
    delay *= self.multiplier
  }
  delay
}

///|
/// Adds deterministic jitter to a retry delay using a caller-provided seed.
pub fn RetryPolicy::delay_with_seed(
  self : RetryPolicy,
  attempt : Int,
  seed : Int,
) -> Int {
  let delay = self.delay_for(attempt)
  if self.jitter_window == 0 {
    return delay
  }
  let span = self.jitter_window * 2 + 1
  let offset = (seed % span + span) % span - self.jitter_window
  let result = delay + offset
  if result < 0 {
    0
  } else if result > self.max_delay {
    self.max_delay
  } else {
    result
  }
}

///|
/// Chooses retry or dead-letter based on the broker's attempt counter.
pub fn RetryPolicy::decide(
  self : RetryPolicy,
  message : Message,
  reason : DeadLetterReason,
  seed : Int,
) -> RetryAction {
  if message.attempts >= self.max_attempts {
    DeadLetter(reason)
  } else {
    Retry(self.delay_with_seed(message.attempts + 1, seed))
  }
}

///|
/// A compact counter used by dead-letter sinks.
pub struct DeadLetterStats {
  mut sent : Int
  mut failed : Int
  mut last_reason : DeadLetterReason?
} derive(Debug)

///|
pub extend DeadLetterStats with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn DeadLetterStats::new() -> DeadLetterStats {
  { sent: 0, failed: 0, last_reason: None, }
}

///|
pub fn DeadLetterStats::record_sent(
  self : DeadLetterStats,
  reason : DeadLetterReason,
) -> Unit {
  self.sent += 1
  self.last_reason = Some(reason)
}

///|
pub fn DeadLetterStats::record_failure(self : DeadLetterStats) -> Unit {
  self.failed += 1
}

///|
pub fn DeadLetterStats::sent(self : DeadLetterStats) -> Int {
  self.sent
}

///|
pub fn DeadLetterStats::failed(self : DeadLetterStats) -> Int {
  self.failed
}
