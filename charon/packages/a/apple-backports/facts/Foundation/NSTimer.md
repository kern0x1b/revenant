# The tolerance of a timer, iOS 7

Source: the host's own Foundation and CoreFoundation, macOS 27, asked with timers of an interval of two
seconds, one-shot and repeating, for a range of tolerances; the device test `tolerance.m` holds iOS 6 to
the same answers.

`-[NSTimer tolerance]` and `CFRunLoopTimerGetTolerance` are one value: what either setter stores, both
getters answer. A new timer has a tolerance of 0, and an invalidated one still takes a new value.

The setter treats the two kinds of timer differently:

- a repeating timer keeps a tolerance that is at most half its interval and takes half its interval for
  anything else - for 5, 100, infinity and a value that is not a number alike. The test is written the way
  round that sends NaN to the half: whatever is not at most the half becomes it. A negative tolerance is
  not at issue there, and a repeating timer keeps -1 as -1;
- a one-shot timer has no interval to measure by, and only a negative tolerance is changed there, to 0:
  100 stays 100, and infinity and a value that is not a number stay what they are.

A repeating timer made with an interval of 0 runs every 0.1 milliseconds, as the release makes it, so its
tolerance is capped at 0.05 milliseconds.

The tolerance lets the system move the timer's firing to save power. iOS 6's run loop has no such
coalescing, so the backport stores the value and answers it as above, and the timer fires when it always
did: that is a hint to a scheduler the release does not run. A timer with a tolerance still fires.
