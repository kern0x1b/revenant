# Percent encoding and the six URL character sets, iOS 7

Source: the host's own Foundation, asked for each set's membership and for each method's answer, and the
differential run of `tests/backports/host/url/run.sh`, which compares the backport with the system over
every one of the 0x110000 scalars for each set and over the encoding and decoding of a large corpus -
7478336 checks, none of them different.

## What each set allows

Every one of the six allows the unreserved characters of RFC 3986 - the letters, the digits, `-`, `.`,
`_` and `~` - and nothing above ASCII at all. What each adds to them is the sub-delimiters its component
may carry:

| set | added to the unreserved characters |
|---|---|
| `URLUserAllowedCharacterSet`, `URLPasswordAllowedCharacterSet` | `!$&'()*+,;=` |
| `URLHostAllowedCharacterSet` | `!$&'()*+,;=` and `:[]` |
| `URLPathAllowedCharacterSet` | `!$&'()*+,;=` and `:@/` |
| `URLQueryAllowedCharacterSet`, `URLFragmentAllowedCharacterSet` | `!$&'()*+,;=` and `:@/?` |

Each set is made once and answered again, so a caller may compare them by identity.

The path set contains `;`: that is the newest implementation, macOS 27, asked for each set's membership. A
line here once kept `;` out because the SDK header documents it as percent-encoded in a path; the rule is
the implementation, not its documentation, and the fuzzer of `tests/backports/host/fuzz` holds all six sets
to the host over every scalar.

`-stringByAddingPercentEncodingWithAllowedCharacters:` looks at which set it is handed, not only at what
the set contains. Given the path set itself, it encodes `:` until the first `/` - `a:b/c:d` becomes
`a%3Ab/c:d` - so that the first segment cannot be read as a scheme; given the host set itself, it encodes
`:`, `[` and `]`, unless the whole string is an IP literal from `[` to `]`, which keeps them: `[::1]` stays
and `[fe80::1%en0]` becomes `[fe80::1%25en0]`, while `host:80` becomes `host%3A80`. A copy of either set, or
any other set, encodes by membership alone. These are the component masks of the newest implementation
(`path`, `pathFirstSegment` and `host` of swift-foundation's URL parser), measured character by character
at the start of a string and after a `/`. The backport compares the set with its own predefined object, which
is the one an application on iOS 6 is handed, and `NSURLComponents`' setters, which encode with those sets,
answer as macOS 27's do: `setHost:@"a:b"` gives `a%3Ab`, `setPath:@"a:b"` gives `a%3Ab`.

## What the two methods do

`-stringByAddingPercentEncodingWithAllowedCharacters:` percent-encodes the UTF-8 of everything the set
does not allow, in upper case hexadecimal: a space becomes `%20`, `ä` becomes `%C3%A4`, an emoji becomes
its four bytes `%F0%9F%98%80`, and a percent sign is encoded like anything else, so `100%%` becomes
`100%25%25`. An empty set encodes everything, letters included. A string that is not valid Unicode - a
lone surrogate - answers nil rather than raising.

`-stringByRemovingPercentEncoding` reads the escapes back as UTF-8 and answers nil when what comes out is
not a string: `%2` at the end, `%zz`, and `%C3` on its own all give nil. Hexadecimal is read in either
case, so `%c3%a4` is `ä`. `%00` decodes to a NUL inside the string, and `+` is left alone - this is not
form encoding.
