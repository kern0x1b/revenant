# The quality of service of a thread, an operation and a queue, iOS 8

Source: the host's own Foundation, macOS 27, asked directly and through the differential run of
`tests/backports/host/foundation2/run.sh`, whose records the device test holds iOS 6 to.

## What the property holds

`NSThread`, `NSOperation` and `NSOperationQueue` answer `NSQualityOfServiceDefault` (-1) until they are
told otherwise, except the main thread and the main queue, which answer `NSQualityOfServiceUserInteractive`
(0x21). They keep only the five values the enumeration names - 0x21, 0x19, 0x11, 0x09 and -1 - and take any
other number as -1: 12345, 0, 1, -2 and 0x15 all read back as -1.

A thread takes a value only before it starts: set on a running thread the property keeps what the thread was
started with, and the main thread keeps its 0x21. An operation and a queue take a value at any time, an
operation even after it has finished.

The quality of service and the thread priority are two properties that do not move each other. An operation
set to the background still reads a `threadPriority` of 0.5, and one given a priority of 0.9 keeps its
quality of service; a thread given a priority of 0.1 still reads -1.

## What it cannot do on iOS 6

A quality of service is a class the kernel of iOS 8 schedules by, and iOS 6 has none: its threads have a
priority and nothing else. Mapping one onto the other would be a formula of our own, and the newest system
shows that the two are kept apart - a thread of quality `Utility` keeps the default scheduling priority of 31
there. So the backport keeps the values and answers them as above, and schedules nothing by them: that is a
hint to a scheduler the release does not run. The same goes for an operation queue's quality of service, which iOS 6's queue,
running its operations on threads of its own, cannot hand them to; the queue says so once in the log. Its
`underlyingQueue` is another matter, and has its own entry: `NSOperationQueueUnderlyingQueue.md`. A thread that runs an operation answers its own quality of service,
not the operation's, since the release starts that thread without it.

The newest system raises no exception but crashes in `pthread_get_qos_class_np` when the quality of service
of a thread that has finished is read; the backport answers the value the thread had.
