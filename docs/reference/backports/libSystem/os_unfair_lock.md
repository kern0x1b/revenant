# os_unfair_lock_lock and os_unfair_lock_unlock on iOS 6

`os_unfair_lock_lock` and `os_unfair_lock_unlock` are iOS 10 additions to libsystem_platform. The iOS 6.1.3 shared cache exports neither, so an image that binds them weakly gets NULL and calls through it, or never starts if the import is strong. The reCAPTCHA Enterprise SDK imports both weakly and without a guard.

`libSystemBackports.dylib` exports `_os_unfair_lock_lock` and `_os_unfair_lock_unlock` (`src/libSystem/RevenantUnfairLock.c`) as `BACKPORT_IMPL`, so the generated trampoline calls the release's function when libsystem_platform has it (iOS 10 and later) and the library's own when it does not.

## What the lock is

The lock is the `apple-compat` implementation, written once in `toolchain/src/apple-compat/src/unfair_lock.h` and included from the package's `share/apple-compat/process-wide` folder, the same header that `libc++abi` of `revenant@libcxx` and the toolchain's own `os_unfair_lock_*` shims compile. The library holds no second copy of the logic, only two calls into it.

It is a real mutual exclusion with the documented behaviour of the release:

- The lock word is `0` when free and holds the owner's Mach thread port with the low bit as the "no waiters" flag when taken. An uncontended lock and unlock leave it `0`.
- A thread that finds the lock taken records that it waits and sleeps in `__ulock_wait`, which is the `pthread_cond_wait` of a hashed bucket (`src/__ulock_wait.c`, `__ulock_wake.c`). It does not spin. The unlock wakes every waiter of the bucket and the waiters compete again.
- Locking a lock the thread owns, unlocking a lock nobody holds and unlocking from a thread that is not the owner print `BUG IN CLIENT OF LIBPLATFORM` and call `abort`. macOS ends the process for the same three mistakes (with a trap rather than `SIGABRT`).

## The choice of primitive

iOS 6 has no `__ulock_wait` and no kernel owner tracking, so the options were `OSSpinLock`, `pthread_mutex` and a wait queue over a condition variable. `OSSpinLock` burns a core while it waits and has no owner check. `pthread_mutex` has no owner word to share with an image that reads it and cannot be unlocked by the "wrong" thread to produce the documented crash. The wait queue gives the documented word and checks, sleeps while it waits and costs one `pthread_mutex` and one `pthread_cond_broadcast` on the contended path only.

## Priority inversion: measured, and a risk

None of the three primitives donates priority on iOS 6.1.3, and the wait queue does not either. Measured on the iPhone 4S (`libsystem_unfair_device_test.lua`, five rounds each): a priority 60 thread waits for a priority 10 thread that holds the lock for 50 ms of work.

| lock | no other load | with two priority 40 busy threads |
|---|---|---|
| `os_unfair_lock` (this library) | 41 to 42 ms | 207 to 2347 ms (an earlier run: 387 to 3115 ms) |
| `pthread_mutex` | 41 to 42 ms | 301 to 1658 ms (382 to 2120 ms) |
| `OSSpinLock` | 41 ms | 230 to 282 ms (206 to 275 ms) |

With no load the three are the same. With busy threads between the two priorities the holder is starved until the timeshare scheduler lets it run, so the waiter's delay is bounded by scheduling and not by the work: from about four to sixty times the work. The library's lock and `pthread_mutex` behave alike, and the spin lock does better only because the waiter that burns the core also lowers its own priority by the decay. The risk therefore exists on this release for every lock, and a lock with a low-priority holder and a high-priority waiter must not sit on a path that has a deadline. The SDK that asked for the symbols takes the lock for short sections.

## Scope and a caveat

Reaches the library: native applications that link `libSystemBackports.dylib` before libSystem, the Swift runtime libraries that link it, and prebuilt images named in `revenant.rebind` (the import moves from libSystem to the library). A stock iOS 6 application has none.

The wait queue is per image. `libc++abi` of `revenant@libcxx` exports one process-wide copy of the same lock and an application's executable may carry the toolchain's static copy, so a process can hold more than one queue. A lock word that is locked through one copy and unlocked through another wakes the waiters of the second queue only, so a waiter of the first stays asleep. A lock used by calls bound to one image, which is how a library uses its own locks, is not affected. The fixture does not test locks shared across copies.

## Tests

`frameworks/Backports/tests/libsystem_unfair/main.c`, built by `libsystem_unfair_test.lua` from the library's sources and the `apple-compat` ones, runs the same seven checks against the library's functions and against the macOS ones: the word after an uncontended lock and unlock, four threads counting 20000 times each and sixteen threads counting 2000 times each with no lost update, a second thread that waits while the lock is held for 100 ms and takes it after the unlock, and the three crashes in a forked child. On the iPhone 4S the same fixture is linked against the built library and passed: 37 checks with the clock checks of [clock_gettime_nsec_np](clock_gettime_nsec_np.md).
