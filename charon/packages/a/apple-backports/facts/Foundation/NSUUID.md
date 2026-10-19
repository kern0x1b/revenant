# NSUUID, iOS 6.0

`NSUUID` arrived in iOS 6.0. The package carries the class for the releases that lack it, 4.3 to 5.1.1 (its registry entry has no
`minimum`); from 6.0 the release's own class answers and the library re-exports it, so the port's code is never in a process there.

Source: swift-corelibs-foundation's `NSUUID.swift`, read for the shape of the class and the archive key; the class as the release of iOS 6.0
(10A403) answers, measured under `xmake emulate -d iPhone3,1 -r 6.0` with a probe of every case below; the same probe on the host's
Foundation (macOS); the armv7 caches of 4.3, 5.0 and 6.0 (`objc.inventory`: `NSUUID` is in none of the first two, `uuid_generate_random`,
`uuid_parse` and `uuid_unparse_upper` are in all three).

## What the port is

The releases make `NSUUID` a class cluster, and so does the port (`Foundation/NSUUID.m`):

- `NSUUID` itself has no state. `+allocWithZone:` on `NSUUID` answers a `__NSConcreteUUID`, a subclass that holds the 16 bytes (its
  class is not exported, as the release's is not); on a subclass of `NSUUID` it answers the subclass. `+UUID` is `[[self alloc] init]`.
- What `NSUUID` answers for a subclass that overrides nothing, the same on 6.0 and on the host: `-getUUIDBytes:` writes 16 zero bytes,
  `-UUIDString` is the empty string, `-hash` is 0, `-copy` is nil, `-init` answers the receiver, and `-initWithUUIDBytes:` and
  `-initWithUUIDString:` answer nil (a subclass is not handed a UUID to hold). `-hash`, `-isEqual:` and `-encodeWithCoder:` go through
  `-getUUIDBytes:`, so a subclass that overrides it is equal to the concrete UUID of those bytes, in both directions, and hashes and
  archives as it.
- The concrete class: `-init` a random UUID (version 4, variant 2, from `uuid_generate_random`); `-initWithUUIDString:` parses with
  `uuid_parse` of the string's UTF-8, so only 36 characters of `8-4-4-4-12` hex digits in either case are a UUID, a NUL ends the
  string (`123E4567-E89B-12D3-A456-426614174000\0extra` parses), and anything else, the empty string, braces, `urn:uuid:`, white
  space, a non-hex digit, is nil; `-initWithUUIDBytes:` copies the bytes; `-getUUIDBytes:` copies them out; `-UUIDString` is upper case
  (`uuid_unparse_upper`); `-copyWithZone:` answers the receiver; `-isEqual:` is true for any `NSUUID` of the same 16 bytes;
  `+supportsSecureCoding` is YES.
- `-hash`: the ELF object-file hash over the 16 bytes (`h = (h << 4) + byte; if the top four bits are set, h ^= they >> 24 and they are
  cleared`) with no final shift, so it is 32 bits and small: 211469392 for 123E4567-E89B-12D3-A456-426614174000, 0 for the zero UUID,
  1114095 for the all-ones one. This is `-[NSData hash]` of the same bytes, on 6.0 for 2000 random UUIDs and on the host; the port's
  answer for 2000 random UUIDs is NSData's too (`device/nsuuid.m`, `host/uuid`).
- The archive: `-encodeWithCoder:` writes the 16 bytes under `NS.uuidbytes` (`encodeBytes:length:forKey:`), `-classForCoder` answers
  `NSUUID`, so an archive names `NSUUID` and is read back as the concrete class; the plist is the same as the host's, class names apart.

## Where the port follows the newest release and not 6.0

Each is measured on 6.0 and on the host, and the port does what the host does, since a UUID that nobody made is worse than a refusal:

| input | 6.0 | host, the port |
|---|---|---|
| `-initWithUUIDString:nil` | the zero UUID | nil |
| `-initWithUUIDBytes:NULL` | crashes (SIGSEGV) | the zero UUID |
| an archive with no `NS.uuidbytes`, or bytes of 0, 15 or 17 bytes | a random UUID (the decoder reads the bytes into a UUID made at random and ignores their length) | `NSInvalidUnarchiveOperationException`: "The data couldn't be read because it is missing." (no key) or "... isn't in the correct format." (a wrong length) |
| `-description` | `<__NSConcreteUUID 0x...> 123E4567-...` | the string alone |

`-getUUIDBytes:NULL` crashes on both. On the release that has the class (6.0 on) none of this is the port's: the release answers.

## Not carried

`-_cfTypeID`, `-_cfUUIDString` and `-_cfUUIDBytes` (the class's private hooks for CoreFoundation), `+automaticallyNotifiesObserversForKey:` of the
concrete class, `-compare:` is the category `NSUUIDCompare.md`, `-launchPersona`, `-uuid` and the XPC and BSXPC coding of the newest
Foundation (no such transport below iOS 6). The archive of a decoded `NSUUID` under a non-keyed coder is not supported by iOS's
`NSCoder` either.

## What was measured of the port

- Host: `tests/backports/host/uuid/run.sh` (the port with its classes renamed against the host's `NSUUID`): parsing of 22 strings, the
  bytes, string, description and hash of six UUIDs, every pair for `isEqual:`, 2000 random UUIDs (version, variant, distinct, NSData's
  hash), the cluster (concrete class, a subclass that overrides nothing, one that overrides `-getUUIDBytes:`), archives of the port
  and of the host in both directions, and five damaged archives; the test fails under three mutants of the port (the hash, the random
  version, the length check).
- Emulator: `tests/backports/device/nsuuid.m` through `below6/run.sh`, on iPhone3,1 6.0 (the release's own class, the reference), and
  iPhone2,1 4.3 and 5.0 with `libFoundationBackports.dylib`: the class comes from the library below 6.0 and from Foundation on 6.0, and
  the answers the program prints are the same on all three except where the table above says.
