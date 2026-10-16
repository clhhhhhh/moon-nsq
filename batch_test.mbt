///|
test "batch accepts bodies until its byte limit" {
  let batch = @moon-nsq.PublishBatch::new(
    "events",
    max_messages=3,
    max_bytes=16,
  )
  assert_true(batch.push(b"a") is @moon-nsq.Added)
  assert_true(batch.push(b"bc") is @moon-nsq.Added)
  assert_eq(batch.encoded_size(), 15)
  assert_true(batch.push(b"d") is @moon-nsq.Full)
  assert_eq(batch.length(), 2)
}

///|
test "batch has an independently enforced message limit" {
  let batch = @moon-nsq.PublishBatch::new(
    "events",
    max_messages=2,
    max_bytes=100,
  )
  assert_true(batch.push(b"a") is @moon-nsq.Added)
  assert_true(batch.push(b"b") is @moon-nsq.Added)
  assert_true(batch.push(b"c") is @moon-nsq.Full)
}

///|
test "batch command drains only when requested" {
  let batch = @moon-nsq.PublishBatch::new("events", max_bytes=100)
  ignore(batch.push(b"a"))
  let first = batch.command()
  assert_eq(batch.length(), 1)
  let second = batch.take_command()
  assert_eq(first, second)
  assert_true(batch.is_empty())
  assert_eq(batch.encoded_size(), 4)
}

///|
test "batch rejects invalid bounds and empty flushes" {
  for
    make in [
      () => @moon-nsq.PublishBatch::new("events", max_messages=0),
      () => @moon-nsq.PublishBatch::new("events", max_bytes=7),
    ] {
    try make() catch {
      _ => ()
    } noraise {
      _ => fail("accepted invalid batch bounds")
    }
  }
  let empty = @moon-nsq.PublishBatch::new("events")
  try empty.command() catch {
    _ => ()
  } noraise {
    _ => fail("encoded empty batch")
  }
}
