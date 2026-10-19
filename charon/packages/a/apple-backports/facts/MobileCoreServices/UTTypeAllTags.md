# UTTypeCopyAllTagsWithClass, iOS 8.0

The release's MobileCoreServices has no `UTTypeCopyAllTagsWithClass` (6.1.3 exports `UTTypeCopyDeclaration`,
`UTTypeConformsTo` and `UTTypeCreatePreferredIdentifierForTag`, and not this one). The SDK's CoreServices header
declares it `API_DEPRECATED("Use the UTType class instead.", ios(8.0, 15.0), ...)`, which is re-read on the day
the function was built. The port builds it in `UIKit/UTTypeAllTags8.m` over the release's own declarations and
a decoder for the identifiers the release makes for tags it has no type for.

The host's answers are the oracle: `tests/backports/host/uttypetags` holds the port to the host's own function
(`differential.m`), and `tests/backports/emulate/uttypetags` runs the same probe on the 6.1.3 guest.

## Declared identifiers

A declared identifier answers its declaration's `UTTypeTagSpecification` for the class. A string value is answered
as a one-element array, an array as itself. The class is absent from the declaration: NULL.

Measured on the host: `public.jpeg` gives `public.filename-extension` `[jpeg, jpg, jpe]` and `com.apple.ostype`
`[JPEG]`; `public.folder` gives `com.apple.ostype` `[fold, fldr, adcL, sbFd]`.

Tags are not inherited. `public.zip-archive` conforms to `public.data` (`UTTypeConformsTo` answers 1), and
`public.data` declares `com.apple.ostype` `[sbFl]`, yet `public.zip-archive` answers `com.apple.ostype` NULL. A type
that does not declare a class answers NULL for it: `public.item` for `com.apple.ostype`. An undeclared identifier
answers NULL for every class.

## Dynamic identifiers

A dynamic identifier is `dyn.a` followed by a base-32 tail. The tail's digits are five bits each, in the alphabet
`abcdefghkmnpqrstuvwxyz0123456789` (the letters `i`, `j`, `l` and `o` are absent), read most significant bit first
and regrouped into eight-bit bytes; a final group of fewer than eight bits is padding. The bytes are the identifier's
records. Two 2012 write-ups describe the format from outside Apple (alastairs-place.net, "UTIs are better than you think,
and here's why", and a MacScripter thread on dynamic UTIs); both say it is undocumented. Their description of the
alphabet, the bit grouping and the record form was checked against the host, case by case, and no code was copied
from either.

The decoded text of `dyn.age80q6xtqk` is `1=frob`, and that of the write-up's `dyn.ah62d4r34gq81k3p2su1zuppgsm10esvvhzxhe55c`
is `?0=7:3=text/X-frob:1=frob`.

The records, measured case by case:

- A record is a key, up to the next `=`, then a value, up to the next `:`. A `:` in a key belongs to the key.
- A key is a class name (`com.apple.ostype=ABCD` answers `[ABCD]`; the match is case-sensitive, so
  `COM.APPLE.OSTYPE=ABCD` answers NULL), or a code for a class. The codes measured: `1` public.filename-extension,
  `2` com.apple.ostype, `3` public.mime-type, `4` com.apple.nspboard-type. `public.pathname` has no code and is written
  by name.
- A code is read from the key's first one or two hex digits, with leading zeros allowed, and the key must be those
  digits alone or one hex digit followed by one more byte that is not a hex digit. So `1`, `03`, `1x`, `1-`, `1 ` and
  `1\xA9` name a class, while `10` (16), `1A` (26), `03x` and `1xA` name none and are looked up as class names.
- A value is a list split by unescaped `,`. An empty value is skipped. `1=,` and `1=` answer NULL.
- A backslash escapes the byte after it; a trailing backslash is kept. `1=a\,b` answers `[a,b]`, `1=a\:b` answers `[a:b]`.
- A record with no `=` after it ends the records, so `x:1=a` answers NULL and `1=a:x:1=b` answers `[a]`. A key that
  is not a class answers nothing and the records go on, so `9=abc:1=q` answers `[q]`.
- Values are UTF-8. A value that is not valid UTF-8 is dropped, but a class with a non-empty value answers an array even
  when every value was dropped: `1=\xE9` answers `[]`, while `1=\xE9,a` answers `[a]`.
- NUL is a byte of the value: `1=a\0b` answers the three characters `a`, U+0000, `b`.
- A `dyn.` prefix is any case, but the format letter after it must be `a`: `Dyn.age80q6xtqk` answers `[frob]`,
  `dyn.bge80q6xtqk` and `DYN.AGE80Q6XTQK` answer NULL.
- The tail's letters are case-insensitive: `dyn.age80Q6XTQK` answers `[frob]`. A digit outside the alphabet, a hyphen,
  or an empty tail answers NULL.
- The conformance key `?0` is not a tag class and is not answered here: it belongs to `UTTypeConformsTo`.

The values are kept as the identifier has them: `dyn.` identifiers made from a MIME type are stored lower case by
`UTTypeCreatePreferredIdentifierForTag`, and the function answers the stored text.

## Host differential

`tests/backports/host/uttypetags/run.sh` builds the port's `UTTypeAllTags8.m` and `UTTypeDynamic8.m` with the host's
`UTTypeIsDynamic` renamed, and compares `UTTypeCopyAllTagsWithClass` on every case below for seven classes:
129 declared identifiers (the SDK constants, `tests/backports/host/uttypeconstants/expected-identifiers.tsv`), the
write-up's examples, the cases above, 200000 generated record texts over an alphabet of separators, escapes, codes,
digits and high bytes, and 4000 generated tails. The run: 1429542 comparisons, 0 mismatches.

Each rule above was first measured on the host with single-case probes, before the port was written, and the
differential then held the port to all of them. The single-case probes are not committed; the differential is.

## Release

Measured on the 6.1.3 guest (iPhone4,1, build 10B329): `tests/backports/emulate/uttypetags` links the port's
`UTTypeAllTags8.m` and `UTTypeDynamic8.m` into `probe.m`, and the run printed 10646 `TAGS` lines, the same count as the
host's own function prints with `host.sh` (`probe.m` alone, against the host). Compared line by line, in order:

- The 2000 generated dynamic identifiers (10000 lines): every answer equals the host's. The decoder runs on the release
  as it does on the host.
- The 129 declared identifiers (645 lines): 46 lines differ, and 10600 of 10646 agree in all. The differences come from
  the declarations, not the decoder, and the release's answer is the one the port gives:
  - 35 lines: the release answers NULL for a class the host declares, for 25 identifiers. The probe does not say whether
    the release leaves each identifier undeclared or declares it without that class. Examples: `public.heic`, `public.heics`, `public.heif`, `public.jpeg-xl`, `org.webmproject.webp`,
    `public.yaml`, `public.css`, `public.swift-source`, `public.utf16-plain-text`, `com.apple.archive`.
  - 11 lines, 10 identifiers: both answer a list, and the lists differ. The release declares fewer extensions or classes
    (`com.apple.protected-mpeg-4-audio` extension `[m4p, m4b]` on the release, `[m4p]` on the host; `public.folder`
    `com.apple.ostype` `[fold, fldr]` on the release, and the host adds `adcL` and `sbFd`), or the same class in another
    order (`public.vcard` mime type: the release answers `directory`, `vcard`, `x-vcard`; the host `vcard`, `directory`,
    `x-vcard`). The port answers the release's list as it is declared.

So the release is the oracle for the declared lists it carries, and the host is the oracle for the decoder. The host's
newer declarations are not what 6.1.3 answers.
