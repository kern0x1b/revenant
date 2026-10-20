# NSCoder, the API of iOS 11.0

Introduced in iOS 11.0: `-decodeValueOfObjCType:at:size:`, the sized twin of
`-decodeValueOfObjCType:at:`.

Source: Foundation of the arm64 shared cache of iOS 11.0, where `NSCoder`'s own
method is the abstract stub that raises through `_NSRequestConcreteImplementation`;
the behaviour that matters is in the concrete coders and is read from the host's
Foundation by `tests/backports/host/foundation11`.

## Behaviour

The size is compared with the size the type encoding stands for
(`NSGetSizeAndAlignment`). A size that does not match raises
`NSInvalidArgumentException` with

    Cannot get decode with size %lu. The type encoded as %s is expected to be %lu bytes

— the odd wording is Apple's own, and the port repeats it. A size that matches
decodes exactly as `-decodeValueOfObjCType:at:` does.

`-[NSValue getValue:size:]`, which arrived in the same release and is backported
in `NSValue+Size.m`, is the same check with `get value` in place of `get decode`.
