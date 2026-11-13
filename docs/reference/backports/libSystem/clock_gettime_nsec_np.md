# clock_gettime_nsec_np on iOS 6

`clock_gettime_nsec_np(clockid_t)` returns a clock reading as one 64-bit count of nanoseconds, and 0 for an identifier it does not know. It arrived in iOS 10 with `clock_gettime`. The iOS 6.1.3 cache exports neither, and the reCAPTCHA Enterprise SDK imports it weakly without a guard.

`libSystemBackports.dylib` exports `_clock_gettime_nsec_np` (`src/libSystem/RevenantClockGettimeNsecNp.c`) as `BACKPORT_IMPL`: the trampoline calls the release's function where it exists and the library's elsewhere. The body is `revenant_clock_gettime_nsec_np` of `apple-compat` (`toolchain/src/apple-compat/src/clock_gettime_nsec_np.c`) over the same `revenant_clock_gettime` that backs `clock_gettime` and `clock_getres`, so there is one implementation.

## The clocks

| identifier | answer on iOS 6.1.3 |
|---|---|
| `CLOCK_REALTIME` | `gettimeofday`, microseconds in nanoseconds |
| `CLOCK_MONOTONIC`, `CLOCK_MONOTONIC_RAW`, `CLOCK_MONOTONIC_RAW_APPROX` | time since boot by the calendar (`gettimeofday` less `kern.boottime`, read twice to be sure the boot time did not change), so it counts the time asleep |
| `CLOCK_UPTIME_RAW`, `CLOCK_UPTIME_RAW_APPROX` | `mach_absolute_time` in nanoseconds, which stops while asleep |
| `CLOCK_PROCESS_CPUTIME_ID` | user and system time of `getrusage(RUSAGE_SELF)` |
| `CLOCK_THREAD_CPUTIME_ID` | user and system time of `thread_info(THREAD_BASIC_INFO)` of the calling thread |
| any other value | 0, with `errno` set to `EINVAL` (macOS does the same for 1, 7 and 100) |

## What differs from macOS

`CLOCK_MONOTONIC_RAW` and `CLOCK_MONOTONIC_RAW_APPROX` are the clock of the hardware that counts sleep, which macOS reads from `mach_continuous_time`. iOS 6 has no such call, so the library answers them as `CLOCK_MONOTONIC`, a count since boot by the calendar. The two clocks run at the same rate for the length of an interval, and the host test checks that: the gain over a 30 ms sleep differs from macOS's by less than 5 ms. Their absolute values differ. On the test host, 34 hours after boot, macOS's value was 9.3 seconds away from the library's, which is the time the calendar has been slewed since boot. Code that takes differences is unaffected, and code that compares a raw reading with another clock's, or stores one across a reboot, is not. `CLOCK_MONOTONIC` agrees with macOS to the microsecond.

## Scope and cost

Every process that loads `libSystemBackports.dylib` on a release before iOS 10, by link order or `revenant.rebind`. On iOS 10 and later nothing is replaced. A call is the trampoline's check and one system call or one `mach_absolute_time`; not timed apart.

## Tests

`frameworks/Backports/tests/libsystem_unfair/main.c`: each of the eight clocks answers, does not run backwards and gains what a 30 ms sleep and 60 ms of work should (the sleep for the wall clocks, the work and not the sleep for the two CPU clocks); every clock but the raw pair agrees with the macOS function within 50 ms (20 ms for the CPU clocks, which on the host agreed within 2 ms); the twelve invalid identifiers answer 0 as macOS's do; and `CLOCK_REALTIME` agrees with `gettimeofday`. All 64 checks of the host run passed, with the lock checks of [os_unfair_lock](os_unfair_lock.md). On the iPhone 4S (iOS 6.1.3) 37 checks passed: the gain over a 30 ms sleep was 32.1 ms for the wall clocks and 31 to 32 ms for the uptime clocks; the process CPU clock gained 54.9 ms and the thread CPU clock 50.2 ms of 60 ms of work (a probe of six rounds read 60.0 ms for both, equal to `getrusage`, so a shorter reading is the phone's other work).
