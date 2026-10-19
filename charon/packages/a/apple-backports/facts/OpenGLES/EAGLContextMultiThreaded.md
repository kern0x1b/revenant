# `EAGLContext.multiThreaded`, and the release's three entry points

The header says one thing about the property: `@property (getter=isMultiThreaded, nonatomic) BOOL
multiThreaded API_AVAILABLE(ios(7.1));` — the context may be used from more than one thread. iOS 7.1
is also the release that added `-initWithAPI:sharedWithCompute:` next to it, and it is the release
after this port's own (6.1.3), which has neither: measured on the armv7 6.1.3 cache, `EAGLContext`
carries `initWithAPI:`, `initWithAPI:properties:`, `initWithAPI:sharegroup:` and
`initWithAPI:sharedWithCompute:`, and no `multiThreaded` accessor.

## What the port does, and why it is not a stored flag

A stored flag would be a property that does nothing, which the port does not ship. So the value is
acted on: the release's context is entered through three entry points that are not safe to enter
twice at once, and with the flag set each of them is serialised behind a recursive lock the port
owns.

The three, all measured in the release's own 6.1.3 metadata as the methods that reach the context's
render storage and the process's current-context slot:

- `+setCurrentContext:` — which context is current is one fact of the process, so this always takes
  the process lock, and additionally the incoming context's own lock when that context is marked, so
  a context cannot be swapped in while another thread is inside it. The two locks are always taken
  in that order, so no pair of threads can hold them the other way round.
- `-renderbufferStorage:fromDrawable:` — allocates the context's renderbuffer.
- `-presentRenderbuffer:` — hands the finished buffer to the drawable.

Every lock is recursive, because a call can reach the context from inside a call that already holds
its lock: presenting the renderbuffer of a context the same code just made current is the ordinary
case, and a non-recursive lock would deadlock on it.

The lock is kept boxed in an `NSValue` in an associated object: a `pthread_mutex_t` is not an object,
and sending it `retain` would be the `NSMapTable` trap this repository already records (`charon`
AGENTS.md, "`NSMapTable` and non-object keys/values"). The flag itself is an `NSNumber`, so it is
associated retained. A mutex that could not be made - `pthread_mutex_init` or the recursive-type set
failing, or the allocation itself - is not stored and not used: the context is then left the way the
release leaves it, unguarded, rather than guarded by a mutex nothing initialised.

## What it costs

The guards are installed the first time any context is marked, and never before: a port that no
application has asked to share a context runs the release's own code with one extra
associated-object read per call, which is what the `dispatch_once` in
`-charon_installMultiThreadedGuards` buys. Installation is idempotent - it happens once per process,
so a second context marked does not wrap anything twice.

The port says so once, in the log, the first time an application marks a context, so a process that
pays for the guards knows why.

## Not measured against a host

There is no differential for this. The host's UIKit has no `EAGLContext` under Mac Catalyst (the
class is iOS-only and the Catalyst headers do not carry it), and a real answer would need a thread
hammering one context from two queues on the device - the device call test is listed in the delivery
as not run. What is measured is the release's own three entry points, which is what the guards
wrap.
