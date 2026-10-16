///|
test "consumer disposition constructors validate delays" {
  assert_true(@moon-nsq.finish_disposition() is @moon-nsq.Finish)
  assert_true(@moon-nsq.requeue_disposition(10) is @moon-nsq.Requeue(10))
  assert_true(@moon-nsq.discard_disposition() is @moon-nsq.Discard)
  try @moon-nsq.requeue_disposition(-1) catch {
    _ => ()
  } noraise {
    _ => fail("accepted a negative retry delay")
  }
}
