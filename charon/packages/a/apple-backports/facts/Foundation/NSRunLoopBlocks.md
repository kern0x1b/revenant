# Blocks on a run loop, iOS 10

Introduced in iOS 10.0: `-[NSRunLoop performBlock:]` and `-[NSRunLoop performInModes:block:]`.

Source: Foundation of the armv7s cache of iOS 10.3.4, read method by method, the host's own Foundation run beside the
port (`host/blocks`), and Foundation of iOS 6.0, which has `-getCFRunLoop` and `CFRunLoopPerformBlock`.

- `-performBlock:` is `-performInModes:` with a list of one mode, `kCFRunLoopDefaultMode`, and the same block.
- `-performInModes:block:` checks the block first: with none it raises `NSInvalidArgumentException` with
  `*** -[NSRunLoop performInModes:block:]: block targets for run loops cannot be nil`. Then the modes: nil or an empty
  array raise `... modes for block performers on run loops cannot be nil or contain no elements`. With neither, the block
  is what the reason names. `-performBlock:` with no block names `-performInModes:block:`, since that is the method that
  raises.
- Otherwise it asks for the receiver's `CFRunLoop`, queues the block on it for the modes with `CFRunLoopPerformBlock`, and
  wakes the loop with `CFRunLoopWakeUp`. The wake-up is what lets a block put on the main run loop from another thread run
  at once and not at the next event; the host test fails without it. The block runs on the thread of the run loop, in the
  modes named, and only while the loop runs in one of them.

Not carried: nothing.
