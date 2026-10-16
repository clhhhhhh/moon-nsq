# moon-nsq

`moon-nsq` is a native MoonBit client library for [NSQ](https://nsq.io/), a
distributed real-time messaging platform. It is being developed for the
MoonBit Open Source Ecosystem Competition.

It currently supports a TCP connection, `IDENTIFY`, `PUB`, `SUB`, `RDY`,
message receipt, `FIN`, `REQ`, heartbeat replies, and binary NSQ V2 frames.

## Development

```bash
moon test --target wasm
moon check --target wasm --deny-warn
```

With `nsqd` listening on its default TCP port, publish a message with:

```bash
moon run cmd/main --target wasm -- 127.0.0.1 orders.created "hello"
```

The command is a deliberately small runnable example; applications should
import `clhhhhhh/moon-nsq` and keep a connection per concurrent consumer.

The repository is original MoonBit code. Its protocol behavior is implemented
from the [NSQ TCP protocol specification](https://nsq.io/clients/tcp_protocol_spec.html).
NSQ itself is distributed under the MIT license; this project is Apache-2.0.
