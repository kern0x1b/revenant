# Reading a URL that carries what a URL cannot, and a promised item, iOS 17.0 and 8.0

Source: the SDK 26.2 headers; the host's own `NSURL` and `NSURLComponents` (measured below).

## The two encoders

With `encodingInvalidCharacters:NO` a character a URL cannot carry makes the whole read answer nil
(measured: `+[NSURL URLWithString:@"https://example.com/a b" encodingInvalidCharacters:NO]` is nil, and
so is the components spelling of the same string). With YES the character is written as a percent
escape, which is what the host writes for a space (`https://example.com/a%20b`).

Three rules the differential corrected here, each of them measured against the host over seven strings:

- **The check is made before the release is asked.** The release's own `+URLWithString:` takes a
  string with a space in it and percent-escapes what it can, so passing the string through answered a
  URL where the modern API with the flag off answers nil. The port now answers nil for a string
  carrying anything outside RFC 3986's unreserved and reserved sets.
- **The readable set is RFC 3986's, not a Foundation URL set.** `URLUserAllowedCharacterSet` leaves
  `/`, `?`, `#` and `:` out, so `https://example.com/` was being refused with the flag off.
- **A percent escape is two hex digits of a byte, so the escape is written from the string's UTF-8
  bytes.** Escaping the UTF-16 unit wrote `%FC` for `ü` where the host writes `%C3%BC`.

`NSURLComponents.encodedHost` is the host as a URL writes it, which is not what the `host` property
reads: a host that arrived with a percent escape reads back decoded and keeps the escape
(measured: `ex%61mple.com` reads as the host `example.com` and the encoded host `ex%61mple.com`), and a
host set with a space in it is written `a%20b`. The port keeps the string the components were read
from and takes the host out of it, and otherwise escapes the host the same way the encoder does.

## A promised item

A promised item is a file the system may not have downloaded yet, and the three methods are what the
value will be once it has. On the port's own release every promised item is a file the file system
already has, so the methods read the file the way `-getResourceValue:forKey:error:` does. The host's
answers, which the port follows: an existing file answers the real size and is reachable; a file that
is not there answers NO with `NSCocoaErrorDomain` code 260 (`NSFileReadNoSuchFileError`), for both
`-getPromisedItemResourceValue:forKey:error:` and
`-checkPromisedItemIsReachableAndReturnError:` (measured).

One case is out of reach and says so: a placeholder whose bytes are still in the iCloud daemon's
hands. 6.1.3 has no entry point that asks the daemon for a promised item's values, so such a key
answers the documented "no value" with that same error rather than a guess.
