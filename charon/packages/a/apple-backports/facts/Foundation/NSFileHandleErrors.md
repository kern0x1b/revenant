# NSFileHandle error variants, iOS 13

The methods that return an error instead of raising: read to end, read up to a length, write, offset, seek, truncate, synchronize, close.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

Every read and write goes through the descriptor with the POSIX call. A failure becomes an NSCocoaErrorDomain error whose code follows the errno (permission, no such file, name too long, out of space, read-only volume, exists, else unknown for the direction) and whose underlying error is the POSIX one. A read at end of file answers empty data, not nil. A closed handle answers EBADF. The descriptor test uses fcntl so a handle closed elsewhere is noticed.
