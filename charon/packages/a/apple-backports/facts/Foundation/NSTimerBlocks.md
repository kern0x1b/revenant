# Timers that run a block, iOS 10

Introduced in iOS 10.0: `+timerWithTimeInterval:repeats:block:`, `+scheduledTimerWithTimeInterval:repeats:block:` and
`-initWithFireDate:interval:repeats:block:` of `NSTimer`.

Source: Foundation of the armv7s cache of iOS 10.3.4, read method by method, and the host's own Foundation run beside
the port on the same timers (`host/blocks`); the device test `blocks.m` holds iOS 6 to the same answers.

The three are one construction. `-initWithFireDate:interval:repeats:block:` makes a private object, an
`_NSTimerBlockTarget` in the release, that keeps a copy of the block and has one method, `-fire:`, which calls the
block with the timer it is given. It then asks the timer's own long initializer, the one iOS has had since 2.0, for a
timer whose target is that object and whose selector is `fire:`, with no user info, and lets go of its own hold on the
object. The timer keeps the object, and so the block, until it is invalidated. The port's object is
`CharonTimerBlockTarget`.

- `+timerWithTimeInterval:repeats:block:` allocates a timer with `-allocWithZone:` on the receiver and initializes it
  with a fire date of now plus the interval and the same interval, and answers it autoreleased. The timer is not on
  any run loop: it does nothing until it is added to one.
- `+scheduledTimerWithTimeInterval:repeats:block:` makes the same timer and adds it to the current run loop in the
  default mode, with `CFRunLoopAddTimer`.
- The block is called with the timer as its argument. A timer that does not repeat is invalid after it has run; one
  that repeats keeps running until it is invalidated, and letting the block go is the timer's doing when it is.

The block must not be nil; the release does not check it, and a timer made with none crashes when it fires, as it does
here.

Not carried: nothing. Every answer above is the same on the host's Foundation and the port's.
