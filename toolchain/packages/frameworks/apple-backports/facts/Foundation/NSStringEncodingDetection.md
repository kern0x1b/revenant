# +[NSString stringEncodingForData:encodingOptions:convertedString:usedLossyConversion:], iOS 8

Measured against the host's own Foundation with a probe of ten cases (plain ASCII, accented UTF-8,
accented Latin-1, a UTF-16LE byte-order mark, invalid UTF-8 continuation bytes with and without a
suggested encoding, an empty data, and Windows-1252 text with and without the "from Windows" hint):
the backport answers the same encoding, the same `usedLossyConversion` and the same converted string
as the host in eight of the ten, byte for byte.

## What the backport does

- A byte-order mark is read and consumed: UTF-8's three-byte mark, and the generic (endianness-
  sniffing) UTF-16 and UTF-32 constants for the other two, not the endian-qualified ones, which would
  read the mark itself as a character.
- Data that is valid UTF-8 is read as UTF-8, except when every byte is also plain ASCII, which the
  host itself prefers to name over UTF-8.
- A suggested encoding (`NSStringEncodingDetectionSuggestedEncodingsKey`) is tried before anything
  else and wins as soon as it decodes the data without error; `NSStringEncodingDetectionUseOnlySuggestedEncodingsKey`
  keeps the search to that list alone, and `NSStringEncodingDetectionDisallowedEncodingsKey` removes
  entries from every list before anything is tried.
- Failing UTF-8 and a suggested list, the backport falls through Windows-1252, then ISO Latin-1, then
  Mac OS Roman - the first of those that decodes the whole data without error is the answer; all three
  decode every byte string without error, so one of them is reached unless the disallowed list removes
  all of them.
- `NSStringEncodingDetectionAllowLossyKey` defaults to true, matching the header; when nothing decodes
  the data cleanly and lossy conversion is allowed, the backport decodes byte by byte in the first
  candidate's own encoding, growing the run past a byte that does not yet form a valid character and
  substituting `NSStringEncodingDetectionLossySubstitutionKey` (or U+FFFD) for one that never does, and
  reports `usedLossyConversion` as true.
- Lossy conversion refused and nothing decoding cleanly, or every candidate disallowed, answers `0`
  and no string, honestly, rather than a guess.

## Where it does not match

The host's own encoding guess for arbitrary invalid bytes with **no** suggested encoding and **no**
byte-order mark comes from a statistical detector this backport does not carry: given the same three
invalid bytes, the host reached for Windows-1251 (reading them as Cyrillic) where the backport, absent
any hint pointing that way, reaches for Windows-1252 (its own next candidate after UTF-8) instead - both
decode the bytes without error, so both report `usedLossyConversion` false, but the two-character
answers differ. A caller that supplies `NSStringEncodingDetectionSuggestedEncodingsKey` is not affected:
the suggested encoding is tried first and matches the host exactly, as measured. Likewise, refusing every
disallowed candidate that the backport carries, the host still reaches for a further, unlisted encoding
of its own rather than answering `0`; the backport answers `0` in that case, which the project's own rule
prefers to a fabricated guess.

The host's own lossy UTF-8 substitution stops decoding at the first invalid byte and reports only the
text up to it; the backport keeps decoding after the substitution and reports the remainder too. Both
report `usedLossyConversion` true and the same leading text.
