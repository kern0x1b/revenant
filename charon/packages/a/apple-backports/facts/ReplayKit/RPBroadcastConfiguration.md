# RPBroadcastConfiguration: the clip configuration of a broadcast, iOS 10 to 11

The configuration an extension hands back with the clips it makes. The port carries the class with its two properties and its
secure coding, and nothing else: the host has no `NSCopying`.

Sources: the `RPBroadcastConfiguration.h` of the macOS 27.0 SDK, and a measurement on the Catalyst host in a windowed app:
`tests/backports/host/replaykit-broadcast/` (cases `configuration`, `configuration-copy`).

## What is measured on the host

| question | host answer |
| --- | --- |
| a fresh configuration: `clipDuration`, `videoCompressionProperties` | 0.0, nil |
| the setters | they store the values, which read back |
| `+supportsSecureCoding` | YES |
| a secure archive, then unarchive, of a configuration with the values set | the class is `RPBroadcastConfiguration`; `clipDuration` reads back 2.5 |
| `-copy` of a configuration | host crash: NSInvalidArgumentException, unrecognized selector `-copyWithZone:` (exit 134); the class has no `NSCopying` |

## What the port answers

- The defaults are the host's: 0.0 and nil.
- `+supportsSecureCoding` is YES. The class encodes `clipDuration` as a double and `videoCompressionProperties` as an object, and
  decodes the object with the classes a dictionary of numbers and strings needs.
- The port has no `NSCopying`, so a copy crashes the same way: the differential's `configuration-copy` case shows the port exiting
  with the same SIGABRT as the host.

## Not measured

- The byte count of the host's archive (280 bytes for the case measured): the port's archive is a different size, because the
  keys and the layout are the port's own. Only the round trip is compared.
- Whether the host archives the compression properties under the same key the port uses.
