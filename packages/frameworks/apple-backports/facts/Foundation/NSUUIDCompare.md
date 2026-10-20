# NSUUID compare:, iOS 15

Source: Foundation of iOS 16.0 arm64e, `-[NSUUID compare:]` at `0x18179d164`, read instruction by instruction; the host's own
`NSUUID` (macOS), measured; and iOS 6.0 on the emulator and iOS 6.1.3 on an iPad 2 and an iPhone 4S, through
`tests/backports/device/ios1516.m`.

## What is read of the newest release

- The method answers `NSOrderedSame` at once when the argument is the receiver itself.
- Otherwise it takes the 16 bytes of each UUID through `-getUUIDBytes:` into buffers it has cleared first, the receiver's and the
  argument's, so an argument that is nil, which answers nothing to that message, compares as the UUID of all zero bytes.
- It goes through the 16 bytes from the last to the first, keeping the difference of the two bytes at each position unless a
  byte nearer the first one differs, which makes the answer that of the first byte that differs, the bytes taken as unsigned
  numbers; the answer is -1 when the receiver's byte is the smaller, 1 when it is the larger and 0 when none differs.

## What the port does

The same: the receiver is compared with the argument by the bytes from the first, and nil is the UUID of zero bytes, so
`[uuid compare:nil]` is 1 for every UUID but the zero one. The class has no such method in iOS 6. It is carried from the band of iOS 4.3, with the class the port makes of `NSUUID` below iOS 6.0 (`NSUUID.md`); the category attaches to that class as it does to the release's.

## What was measured

The host's `NSUUID` answered the 24 by 24 pairs of twelve chosen UUIDs - the extremes, neighbours that differ in one byte at each
end, and the UUID of the beacon documentation - and twelve random ones, and the comparison with nil for each; the device test holds
the port to those 600 answers, which are the same on the emulated iOS 6.0, the iPad 2 and the iPhone 4S.
