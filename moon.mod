// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "clhhhhhh/moon-nsq"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/clhhhhhh/moon-nsq"

license = "Apache-2.0"

keywords = [ "nsq", "message-queue", "client", "async" ]

preferred_target = "wasm"

description = "A native MoonBit client library for the NSQ messaging platform."

import {
  "moonbitlang/async@0.22.1",
}
