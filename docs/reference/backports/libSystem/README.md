# libSystem Backports

The iOS 6.1.3 dyld cache does not export `clock_getres`, `futimens`, `readlinkat`, `symlinkat` or `utimensat`. `SystemBackports` supplies the missing names for code linked against a newer SDK.

`clock_getres` forwards to the shared `apple-compat` implementation so the toolchain and Backports use one implementation.

The `*at` file operations accept `AT_FDCWD` and directory descriptors. Absolute paths ignore `dirfd`. Relative paths with a directory descriptor validate the descriptor with `fstat`, reject non-directories with `ENOTDIR`, and resolve the directory path with `F_GETPATH` before invoking the iOS 6 path-based operation. This preserves the path selected at resolution time, but it is not atomic with a concurrent directory rename between `F_GETPATH` and the operation.

`readlinkat` delegates to `readlink`, preserving its byte count and non-terminating output behavior. `symlinkat` delegates to `symlink`. `futimens` and `utimensat` validate nanoseconds, translate `UTIME_NOW` and `UTIME_OMIT`, preserve omitted timestamps, and use the iOS 6 microsecond timestamp operations. `AT_SYMLINK_NOFOLLOW` on a symlink uses an `O_SYMLINK` descriptor and `futimes`.

Host behavior is compared against macOS system calls by `frameworks/Backports/tests/libsystem_at_test.lua`. The fixture also ran on an iPhone 4S with iOS 6.1.3. Its `futimes` and no-follow symlink timestamp checks measured whole-second timestamp precision on the device, while the host checks measured microsecond parity with native calls.

The host probe accepted `tv_nsec = 1000000000` in `futimens` without an error, while this compatibility implementation enforces the POSIX `0..999999999` range and returns `EINVAL` as specified for the API. The host test therefore checks this invalid-input case against the required error directly rather than treating the observed host result as the expected behavior.
