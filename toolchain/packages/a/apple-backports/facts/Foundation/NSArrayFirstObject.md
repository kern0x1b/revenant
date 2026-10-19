# NSArray firstObject, iOS 4.0

Source: the host's own Foundation, held against the backport by the `array.firstObject` record of
`tests/backports/host/foundation2/run.sh`, which asks eight arrays and a mutable one as it is emptied; and iOS 6.0
and 6.1.3 on the emulator, an iPhone 4S and an iPad 2, through `tests/backports/device/foundation2.m`.

`-firstObject` answers the object at index 0, and nil for an empty array, where `objectAtIndex:0` raises. It does
not skip an `NSNull`: an array whose first element is the null answers the null, and nil is only what the empty
array answers. It reads the current state of a mutable array - the first object after the first was removed is the
next one, and nil once the array is emptied - and it answers the same for the array a subarray, a concatenation
and an ordered set make.

The method is public from iOS 4.0, and iOS 6.0 and 6.1.3 answer it themselves: the port adds it to `NSArray` only
where the class does not answer it, so on those releases the answers above are the release's own, and the device run
holds them to the records the host wrote. `NSMutableArray` and the classes behind the class cluster inherit it either
way.
