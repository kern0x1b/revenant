# NSValue getValue:size:, iOS 11

Source: the host's own Foundation, held against the backport by the `value.*` records of
`tests/backports/host/foundation2/run.sh`; and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad 2,
through `tests/backports/device/foundation2.m`.

`-getValue:size:` copies the value into the buffer when the size is the size of the value's type, and raises
`NSInvalidArgumentException` when it is not, writing nothing. A value made from the eight bytes of a double answers
the same eight bytes for a size of 8 and raises for a size of 4; a value made with `valueWithRange:` fills an
`NSRange` for a size of `sizeof(NSRange)`. The port measures the size of the type with `NSGetSizeAndAlignment`
and then calls `-getValue:` of the release, which is the method the newest release's own version ends in.
