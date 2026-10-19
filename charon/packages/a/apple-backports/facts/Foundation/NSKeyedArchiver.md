# NSKeyedArchiver, the API of iOS 10.0 and 11.0

An archiver that carries its own buffer and hands it over with `-encodedData`,
which the SDK's availability gives to iOS 10.0, and the two members iOS 11.0
added: an archiver created requiring secure coding, and one call that archives
an object.

Source: Foundation of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372) and of
iOS 12.0; the current behaviour from the differential test against the host's
Foundation (`tests/backports/host/keyedarchive11`); iOS 6's own behaviour from
the armv7 caches of 6.0, 6.1.3 and 6.1.6.

| method | address in 11.0 |
|---|---|
| `+archivedDataWithRootObject:requiringSecureCoding:error:` | `0x181556290` |
| `-initRequiringSecureCoding:` | `0x18155624c` |
| `-encodedData` | `0x181552e94` |
| `-_initWithOutput:` | `0x1814e461c` |

## Behaviour

| member | behaviour |
|---|---|
| `-initRequiringSecureCoding:` | `-init`, then `-setRequiresSecureCoding:` with the flag. Nothing else. |
| `-encodedData` | see below; it finishes the archive itself. |
| `+archivedDataWithRootObject:requiringSecureCoding:error:` | `alloc`, `-initRequiringSecureCoding:`, `-encodeObject:forKey:@"root"`, `-encodedData`, `release`. |

`-init` in 11.0 gives the archiver a buffer of its own through
`-_initWithOutput:`, which sets the output format to `200`
(`NSPropertyListBinaryFormat_v1_0`) and clears the rest. iOS 6 has no such
`-init`, so the port makes an `NSMutableData` itself and calls
`-initForWritingWithMutableData:`, keeping the buffer as an associated object.
The output format is `200` there too, which the differential test confirms.

The root is archived under `@"root"`, the `NSKeyedArchiveRootObjectKey` the old
`+archivedDataWithRootObject:` already used.

## `-encodedData`, branch by branch

1. The output (the field at offset 8, which iOS 6 calls `_stream`) is not of the
   expected class: an empty `NSMutableData` comes back. This is the archiver
   that writes somewhere other than memory.
2. Otherwise, if bit `0x2` of the flags field is clear, the archive is not
   finished yet and `-finishEncoding` runs.
3. The buffer itself is returned, retained and autoreleased — **not a copy**.

Two observable consequences the port has to keep: the answer is **mutable**, and
a second call hands back **the same object**.

The port keeps its own record of having finished, in an associated object,
rather than reading the flags field, and rests on one fact about iOS 6:
`-finishEncoding` with bit `0x2` already set returns at once and leaves the
archive alone (`-[NSKeyedArchiver finishEncoding]` at `0x319dbf35` in 6.1.3
tests `#2` and branches to its exit, and sets the bit with `orr r0, r0, #2` on
the way out). The device test checks exactly that.

For an archiver the port did not create, the buffer comes from the private
`_stream` field, whose name is confirmed in 6.0, 6.1.3 and 6.1.6, and only when
it holds an `NSMutableData`. Where the field is missing or holds something else,
branch 1 applies.

## The error argument

In **11.0 and 12.0 the `error` argument is never read**, on any branch: an
exception from encoding reaches the caller and takes the application with it.
The current implementation answers `nil` instead and fills in
`NSCocoaErrorDomain` `4866` (`NSCoderInvalidValueError`) with an
`NSUnderlyingError` of `4864` describing the refusal.

The port implements the current behaviour, since applications are built against
a recent SDK and are written for `nil` with an error. The text of the underlying
error comes from iOS 6's exception and does not match Apple's word for word;
that is the one divergence allowed here, and the registry records it.

## Exceptions

Encoding into a finished archive raises `NSInvalidArchiveOperationException`
with `%@: archive already finished, %@` (the strings sit at `0x1a97888a0` and
`0x1a9788a00` in 11.0). iOS 6 raises the same exception with its own wording.
