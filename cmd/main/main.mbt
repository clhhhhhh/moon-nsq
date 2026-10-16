///|
/// Publishes one UTF-8 message to an NSQ instance at the default TCP port.
fn main {
  @async.run_async_main(() => {
    let args = @env.args()
    if args.length() != 4 {
      println("usage: moon run cmd/main -- <host> <topic> <message>")
    } else {
      let connection = @lib.connect(args[1], 4150)
      defer connection.close()
      connection.identify()
      connection.publish(args[2], @utf8.encode(args[3]))
      println("published to \{args[2]}")
    }
  })
}
