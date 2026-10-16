///|
/// A TCP endpoint advertised by `nsqlookupd`.
pub struct ProducerEndpoint {
  broadcast_address : String
  tcp_port : Int
  http_port : Int
  version : String
} derive(Debug, FromJson)

///|
pub extend ProducerEndpoint with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProducerEndpoint with FromJson::{from_json}

///|
pub fn ProducerEndpoint::new(
  broadcast_address : String,
  tcp_port : Int,
  http_port? : Int = 0,
  version? : String = "",
) -> ProducerEndpoint raise ProtocolError {
  if broadcast_address.length() == 0 || broadcast_address.contains(" ") {
    raise InvalidOption("producer broadcast address must not be empty")
  }
  if tcp_port < 1 || tcp_port > 65_535 || http_port < 0 || http_port > 65_535 {
    raise InvalidOption("producer ports must be valid TCP ports")
  }
  { broadcast_address, tcp_port, http_port, version, }
}

///|
/// Returns a host-and-port string accepted by `connect`.
pub fn ProducerEndpoint::address(self : ProducerEndpoint) -> String {
  "\{self.broadcast_address}:\{self.tcp_port}"
}

///|
struct LookupResponse {
  producers : Array[ProducerEndpoint]
} derive(FromJson)

///|
pub extend LookupResponse with FromJson::{from_json}

///|
/// An HTTP endpoint of an `nsqlookupd` process.
pub struct Lookupd {
  base_url : String
} derive(Debug)

///|
pub extend Lookupd with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn Lookupd::new(
  host : String,
  port? : Int = 4161,
) -> Lookupd raise ProtocolError {
  if host.length() == 0 || host.contains("/") || host.contains(" ") {
    raise InvalidOption("lookupd host must be a hostname or IP address")
  }
  if port < 1 || port > 65_535 {
    raise InvalidOption("lookupd port must be between 1 and 65535")
  }
  { base_url: "http://\{host}:\{port}", }
}

///|
fn lookup_response(
  body : String,
) -> Array[ProducerEndpoint] raise ProtocolError {
  try {
    let response : LookupResponse = @json.from_json(@json.parse(body))
    for producer in response.producers {
      if producer.broadcast_address.length() == 0 ||
        producer.tcp_port < 1 ||
        producer.tcp_port > 65_535 {
        raise InvalidOption("lookupd returned an invalid producer endpoint")
      }
    }
    response.producers
  } catch {
    _ => raise InvalidOption("lookupd returned invalid JSON")
  }
}

///|
/// Looks up brokers responsible for a topic through the nsqlookupd HTTP API.
pub async fn Lookupd::lookup(
  self : Lookupd,
  topic : String,
) -> Array[ProducerEndpoint] {
  validate_name(topic)
  let (response, body) = @http.get("\{self.base_url}/lookup?topic=\{topic}")
  if response.code != 200 {
    raise ServerError("lookupd returned HTTP \{response.code}")
  }
  lookup_response(body.text())
}

///|
/// Queries `/ping` and returns whether this lookupd endpoint is reachable.
pub async fn Lookupd::ping(self : Lookupd) -> Bool {
  try {
    let (response, body) = @http.get("\{self.base_url}/ping")
    response.code == 200 && body.text() == "OK"
  } catch {
    _ => false
  }
}

///|
/// A nonempty round-robin set of broker TCP endpoints.
pub struct BrokerSet {
  mut producers : Array[ProducerEndpoint]
  mut next_index : Int
}

///|
fn validate_producers(
  producers : Array[ProducerEndpoint],
) -> Unit raise ProtocolError {
  if producers.length() == 0 {
    raise InvalidOption("at least one producer endpoint is required")
  }
  for index in 0..<producers.length() {
    let producer = producers[index]
    ignore(
      ProducerEndpoint::new(
        producer.broadcast_address,
        producer.tcp_port,
        http_port=producer.http_port,
        version=producer.version,
      ),
    )
    let next = index + 1
    for later in next..<producers.length() {
      if producer.address() == producers[later].address() {
        raise InvalidOption(
          "duplicate producer endpoint: \{producer.address()}",
        )
      }
    }
  }
}

///|
pub fn BrokerSet::new(
  producers : Array[ProducerEndpoint],
) -> BrokerSet raise ProtocolError {
  validate_producers(producers)
  { producers: producers.copy(), next_index: 0, }
}

///|
pub fn BrokerSet::length(self : BrokerSet) -> Int {
  self.producers.length()
}

///|
/// Selects a broker and advances the round-robin cursor.
pub fn BrokerSet::next(self : BrokerSet) -> ProducerEndpoint {
  let producer = self.producers[self.next_index]
  self.next_index = (self.next_index + 1) % self.producers.length()
  producer
}

///|
/// Replaces all endpoints atomically after a discovery refresh.
pub fn BrokerSet::replace(
  self : BrokerSet,
  producers : Array[ProducerEndpoint],
) -> Unit raise ProtocolError {
  validate_producers(producers)
  self.producers = producers.copy()
  self.next_index = 0
}

///|
/// Refreshes this broker set from the provided nsqlookupd endpoint.
pub async fn BrokerSet::refresh(
  self : BrokerSet,
  lookupd : Lookupd,
  topic : String,
) -> Unit {
  self.replace(lookupd.lookup(topic))
}
