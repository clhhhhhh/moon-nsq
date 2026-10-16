///|
/// HTTP operation used by an nsqd/nsqlookupd administration client.
pub enum AdminOperation {
  CreateTopic(String)
  DeleteTopic(String)
  CreateChannel(String, String)
  DeleteChannel(String, String)
  Tombstone(String)
  Pause(String)
  Unpause(String)
} derive(Debug, Eq)

///|
pub extend AdminOperation with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AdminOperation with Eq::{equal, not_equal}

///|
/// Constructors kept explicit so callers can build operations without matching internals.
pub fn create_topic_operation(topic : String) -> AdminOperation {
  CreateTopic(topic)
}

///|
pub fn delete_topic_operation(topic : String) -> AdminOperation {
  DeleteTopic(topic)
}

///|
pub fn create_channel_operation(
  topic : String,
  channel : String,
) -> AdminOperation {
  CreateChannel(topic, channel)
}

///|
pub fn delete_channel_operation(
  topic : String,
  channel : String,
) -> AdminOperation {
  DeleteChannel(topic, channel)
}

///|
pub fn tombstone_operation(topic : String) -> AdminOperation {
  Tombstone(topic)
}

///|
pub fn pause_operation(topic : String) -> AdminOperation {
  Pause(topic)
}

///|
pub fn unpause_operation(topic : String) -> AdminOperation {
  Unpause(topic)
}

///|
/// Validates an admin operation before it becomes an HTTP path.
pub fn AdminOperation::validate(
  self : AdminOperation,
) -> Unit raise ProtocolError {
  match self {
    CreateTopic(topic)
    | DeleteTopic(topic)
    | Tombstone(topic)
    | Pause(topic)
    | Unpause(topic) => validate_name(topic)
    CreateChannel(topic, channel) | DeleteChannel(topic, channel) => {
      validate_name(topic)
      validate_name(channel)
    }
  }
}

///|
/// Produces the relative endpoint path used by the NSQ HTTP API.
pub fn AdminOperation::path(
  self : AdminOperation,
) -> String raise ProtocolError {
  self.validate()
  match self {
    CreateTopic(topic) => "/topic/create?topic=\{topic}"
    DeleteTopic(topic) => "/topic/delete?topic=\{topic}"
    CreateChannel(topic, channel) =>
      "/channel/create?topic=\{topic}&channel=\{channel}"
    DeleteChannel(topic, channel) =>
      "/channel/delete?topic=\{topic}&channel=\{channel}"
    Tombstone(topic) => "/topic/tombstone?topic=\{topic}"
    Pause(topic) => "/topic/pause?topic=\{topic}"
    Unpause(topic) => "/topic/unpause?topic=\{topic}"
  }
}

///|
/// Returns the HTTP method used for an administrative operation.
/// nsqd exposes these state-changing administration endpoints as GET routes.
pub fn AdminOperation::http_method(self : AdminOperation) -> String {
  match self {
    CreateTopic(_)
    | DeleteTopic(_)
    | CreateChannel(_, _)
    | DeleteChannel(_, _)
    | Tombstone(_)
    | Pause(_)
    | Unpause(_) => "GET"
  }
}

///|
/// Returns whether the operation changes broker state.
pub fn AdminOperation::is_mutating(self : AdminOperation) -> Bool {
  self.http_method() == "GET"
}

///|
/// Returns a concise operation label for logs and metrics.
pub fn AdminOperation::label(self : AdminOperation) -> String {
  match self {
    CreateTopic(_) => "topic.create"
    DeleteTopic(_) => "topic.delete"
    CreateChannel(_, _) => "channel.create"
    DeleteChannel(_, _) => "channel.delete"
    Tombstone(_) => "topic.tombstone"
    Pause(_) => "topic.pause"
    Unpause(_) => "topic.unpause"
  }
}

///|
/// Simple URL builder for an nsqd administration endpoint.
pub struct AdminClient {
  host : String
  port : Int
  base_path : String
} derive(Debug)

///|
pub extend AdminClient with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn AdminClient::new(
  host : String,
  port? : Int = 4151,
  base_path? : String = "",
) -> AdminClient raise ProtocolError {
  if host.length() == 0 || host.contains("/") || host.contains(" ") {
    raise InvalidOption("admin host must be a hostname or IP address")
  }
  if port < 1 || port > 65_535 {
    raise InvalidOption("admin port must be a valid TCP port")
  }
  if base_path.contains("?") || base_path.contains(" ") {
    raise InvalidOption("admin base path contains invalid characters")
  }
  { host, port, base_path, }
}

///|
pub fn AdminClient::host(self : AdminClient) -> String {
  self.host
}

///|
pub fn AdminClient::port(self : AdminClient) -> Int {
  self.port
}

///|
/// Builds an absolute HTTP URL without performing network I/O.
pub fn AdminClient::url(
  self : AdminClient,
  operation : AdminOperation,
) -> String raise ProtocolError {
  "http://\{self.host}:\{self.port}\{self.base_path}\{operation.path()}"
}

///|
/// Builds a health endpoint URL.
pub fn AdminClient::health_url(self : AdminClient) -> String {
  "http://\{self.host}:\{self.port}\{self.base_path}/info"
}

///|
/// Builds a stats endpoint URL with the requested format.
pub fn AdminClient::stats_url(
  self : AdminClient,
  format? : String = "json",
) -> String raise ProtocolError {
  if !(format == "json" || format == "text") {
    raise InvalidOption("stats format must be json or text")
  }
  "http://\{self.host}:\{self.port}\{self.base_path}/stats?format=\{format}"
}
