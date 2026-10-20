# NSIndexPath getIndexes:range:, iOS 7

Source: the host's own Foundation, asked for three paths and nine ranges each and held against the backport by the
27 `indexPath.*` records of `tests/backports/host/foundation2/run.sh`; and iOS 6.0 and 6.1.3 on the emulator, an
iPhone 4S and an iPad 2, through `tests/backports/device/foundation2.m`.

`-getIndexes:range:` copies the indexes of the positions in the range into the buffer, in order, and writes nothing
else. The range is checked before anything is written, and it is out of bounds when its location is past the
length of the path or its length is more than what remains after the location:

- a path of five indexes answers the whole range 0 to 5 and the part 1 to 3, writes nothing for an empty range at 5,
  which is the end and is allowed, and writes one index for 4 to 1;
- 4 to 2 goes past the end and raises `NSRangeException` with nothing written, and so do an empty range at 6 (past the
  end), a location of `NSNotFound`, a length of `NSUIntegerMax` and a location of `NSUIntegerMax`;
- an empty path and a path of one index raise for every one of the nine ranges that goes past their length,
  including the empty range at 5.

The buffer is untouched when the call raises: the record holds the eight words the test filled with 99 before the
call, and they are 99 after it.
