///|
/// Durable topic configuration used by provisioning tools.
pub struct TopicSpec {
  name : String
  partitions : Int
  retention_days : Int
  max_message_bytes : Int
} derive(Debug)

///|
pub extend TopicSpec with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn TopicSpec::new(
  name : String,
  partitions? : Int = 1,
  retention_days? : Int = 7,
  max_message_bytes? : Int = 1_000_000,
) -> TopicSpec raise ProtocolError {
  validate_name(name)
  if partitions < 1 || partitions > 1_024 {
    raise InvalidOption("partitions must be between 1 and 1024")
  }
  if retention_days < 0 || retention_days > 3_650 {
    raise InvalidOption("retention_days must be between 0 and 3650")
  }
  if max_message_bytes < 1 || max_message_bytes > max_frame_size - 30 {
    raise InvalidOption("max_message_bytes exceeds NSQ frame capacity")
  }
  { name, partitions, retention_days, max_message_bytes, }
}

///|
pub fn TopicSpec::name(self : TopicSpec) -> String {
  self.name
}

///|
pub fn TopicSpec::partitions(self : TopicSpec) -> Int {
  self.partitions
}

///|
pub fn TopicSpec::retention_days(self : TopicSpec) -> Int {
  self.retention_days
}

///|
pub fn TopicSpec::max_message_bytes(self : TopicSpec) -> Int {
  self.max_message_bytes
}

///|
/// Channel configuration paired with a topic.
pub struct ChannelSpec {
  topic : String
  name : String
  max_in_flight : Int
  max_attempts : Int
} derive(Debug)

///|
pub extend ChannelSpec with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn ChannelSpec::new(
  topic : String,
  name : String,
  max_in_flight? : Int = 1,
  max_attempts? : Int = 5,
) -> ChannelSpec raise ProtocolError {
  validate_name(topic)
  validate_name(name)
  if max_in_flight < 1 || max_in_flight > 2_500 {
    raise InvalidOption("channel max_in_flight must be between 1 and 2500")
  }
  if max_attempts < 1 || max_attempts > 65_535 {
    raise InvalidOption("channel max_attempts must be between 1 and 65535")
  }
  { topic, name, max_in_flight, max_attempts, }
}

///|
pub fn ChannelSpec::topic(self : ChannelSpec) -> String {
  self.topic
}

///|
pub fn ChannelSpec::name(self : ChannelSpec) -> String {
  self.name
}

///|
pub fn ChannelSpec::max_in_flight(self : ChannelSpec) -> Int {
  self.max_in_flight
}

///|
pub fn ChannelSpec::max_attempts(self : ChannelSpec) -> Int {
  self.max_attempts
}

///|
/// A validated provisioning plan for one topic and its channels.
pub struct TopologyPlan {
  topic : TopicSpec
  channels : Array[ChannelSpec]
} derive(Debug)

///|
pub extend TopologyPlan with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn TopologyPlan::new(
  topic : TopicSpec,
  channels : Array[ChannelSpec],
) -> TopologyPlan raise ProtocolError {
  if channels.length() == 0 {
    raise InvalidOption("topology plan needs at least one channel")
  }
  for channel in channels {
    if channel.topic() != topic.name() {
      raise InvalidOption("channel topic does not match topology topic")
    }
  }
  for i in 0..<channels.length() {
    for j in (i + 1)..<channels.length() {
      if channels[i].name() == channels[j].name() {
        raise InvalidOption("topology plan contains duplicate channels")
      }
    }
  }
  { topic, channels: channels.copy(), }
}

///|
pub fn TopologyPlan::topic(self : TopologyPlan) -> TopicSpec {
  self.topic
}

///|
pub fn TopologyPlan::channels(self : TopologyPlan) -> Array[ChannelSpec] {
  self.channels.copy()
}

///|
pub fn TopologyPlan::contains_channel(
  self : TopologyPlan,
  name : String,
) -> Bool {
  for channel in self.channels {
    if channel.name() == name {
      return true
    }
  }
  false
}
