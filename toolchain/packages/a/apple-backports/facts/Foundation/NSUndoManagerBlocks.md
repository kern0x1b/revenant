# -[NSUndoManager registerUndoWithTarget:handler:], iOS 9

Introduced in iOS 9.0 (macOS 10.11): registers an undo action as a block instead of a
target/selector/object triple. Measured against the host's own Foundation with a small probe
(`registerUndoWithTarget:handler:` on a real `NSUndoManager`, setting a property, undoing it):
the value is restored, `canRedo` stays false afterwards because the handler itself did not
register a further undo - the host answers exactly the same, and the backport matches it.

Apple's own documentation warns that `target` is not retained by the registration; the host's
own Foundation demonstrates why - letting `target` be deallocated before `-undo` fires and then
calling `-undo` crashes the host process itself (a dangling reference, not a checked one). The
backport does not reproduce that crash: `target` is held weakly by the invoker object the
category registers instead, and a target that is gone by the time undo fires is treated as
"nothing to do" rather than as a dangling send. This is a deliberate divergence, not an
oversight - a backport must not crash a caller who leans on documented-but-fragile host
behaviour, per the project's own rule that no API may crash its caller.

## How the port does it

`registerUndoWithTarget:handler:` wraps the caller's target and block in a small invoker object
and registers that invoker with the real `-registerUndoWithTarget:selector:object:`, using the
invoker itself as both the target and the retained object; the invoker's own method reads back
its weak target and runs the block only if it is still alive. One consequence of registering the
invoker rather than the caller's own target is that `-removeAllActionsWithTarget:` called with
the caller's original target does not reach an action registered this way; nothing in this
backport's own call sites relies on it.
