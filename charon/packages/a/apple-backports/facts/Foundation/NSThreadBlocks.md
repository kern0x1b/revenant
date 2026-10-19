# Threads that run a block, iOS 10

Introduced in iOS 10.0: `-[NSThread initWithBlock:]` and `+[NSThread detachNewThreadWithBlock:]`.

Source: Foundation of the armv7s cache of iOS 10.3.4, read method by method, the host's own Foundation run beside the
port (`host/blocks`), and Foundation of iOS 6.0, which has `-[NSBlock invoke]` and `NSThread`'s long initializer.

- `-initWithBlock:` with no block lets go of the thread and raises `NSInvalidArgumentException` with the reason
  `*** -[NSThread initWithBlock:]: block targets for threads cannot be nil`. With one, it copies the block and asks the
  thread's own `-initWithTarget:selector:object:` for a thread whose target is the block, whose selector is `invoke` and
  whose object is nil, then lets go of its copy. The block is called on the thread's own thread once it is started, as
  any target is; before `-start` nothing runs.
- `+detachNewThreadWithBlock:` with no block raises the same with `+[NSThread detachNewThreadWithBlock:]` in front.
  With one it does not make an `NSThread` first: it copies the block and starts a detached pthread of system scope, with
  the copy as its argument. The thread puts the copy in a thread-specific slot whose destructor releases it, so the block
  is let go when the thread ends (the destructor is `_Block_release`), pushes an autorelease pool, calls the block and
  pops the pool.

The text in front of the reason is what Foundation's `_NSMethodExceptionProem` makes: `*** `, `+` or `-` by whether the
receiver is a class, the class name and the selector. A nil receiver reads `*** +[nil selector]`.

The port carries the same, except that a thread that cannot be created lets the copy go at once, where the release
leaves it held.
