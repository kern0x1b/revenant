# UIPrinterDestination, iOS 14.5

Introduced in iOS 14.5 as the value a print service extension returns for a printer it found: a URL, a display name and
a TXT record. `NSSecureCoding`. The SDK 16.4 header is the contract (`UIPrintServiceExtension.h`, the same header as
`UIPrintServiceExtension`): `-initWithURL:`, and three read-write properties (`URL`, `displayName`, `txtRecord`), all 14.5.

The release (6.1.3) has no print service extension, so no destination reaches an application from the system. The class
is still a value an application can make, archive and read back, which is what the port keeps.

## Answers, measured on the host

A probe on Mac Catalyst, and the differential in `tests/backports/host/uikit-printer/` for the matching lines:

- `-initWithURL:` keeps the URL it was given; `displayName` and `txtRecord` are nil.
- `-initWithURL:nil` works and answers a destination with a nil URL. A bare `-init` works and answers the same.
- `+supportsSecureCoding` is YES.
- The three properties read back what was set.

## Open difference: the host's archive does not decode

The host writes an archive with `+archivedDataWithRootObject:requiringSecureCoding:error:` (459 bytes, no error) and
then cannot read it back: `+unarchivedObjectOfClass:fromData:error:` returns nil with "The data couldn't be read because
it isn't in the correct format." The host's archive format is not known, so the port does not copy it.

The port archives its own keys: `URL`, `displayName` and `txtRecord`, one object per property, decoded with class checks
(`decodeObjectOfClass:forKey:`). Its round trip works: a destination archived with a URL, a name and nothing else reads
back with the same URL and name. The differential prints this round trip on both sides as `open:` lines and does not
compare them, because the two answers differ by design.

## What the port does

- `-initWithURL:` copies the URL (copy, as the header's property is copy); the other properties start nil.
- `-initWithCoder:` answers nil for a coder that does not allow keyed coding; otherwise it decodes the three keys with
  class checks, so a value of the wrong class is refused under secure coding.
- `-encodeWithCoder:` writes the three keys to a keyed coder and does nothing on any other coder.

## Open

- The host's archive format is not matched (above).
- Nothing on the 6.1.3 device creates a destination: there is no extension system to make one, so the class is measured
  only as a value.

## Device

Not run on a device. A destination is a value; nothing about it needs the printing system on 6.1.3.
