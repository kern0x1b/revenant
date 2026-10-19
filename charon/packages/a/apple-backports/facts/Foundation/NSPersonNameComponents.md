# NSPersonNameComponents, iOS 9.0

Introduced in iOS 9.0: the parts of a person's name - prefix, given, middle, family, suffix, nickname and a phonetic
representation that is itself name components - that `NSPersonNameComponentsFormatter` turns into a string.

Source: the host's own Foundation under Mac Catalyst, asked for each answer below and held against the backport by
`tests/backports/host/personname/run.sh`, fourteen records that `tests/backports/device/personname.m` compares on a device
running 6.1.3.

- A new object has no part set, and the superclass is NSObject.
- Each string part is **copied** on the way in: a mutable string changed afterwards is not the part. Setting nil clears it.
- The phonetic representation is copied as well, so the object read back is not the one set.
- `-copy` is another object with every part equal to the original's, its phonetic representation copied again, and equal
  and of the same hash; changing the copy leaves the original.
- `-isEqual:` compares the seven parts, the phonetic representation by its own equality; two empty objects are equal. The
  host's `-isEqual:` **raises** for an argument that is not name components (a string is sent `-nickname`); the port answers NO.
- The class adopts `NSSecureCoding` and `NSCopying`. A secure round trip through a keyed archive gives an equal object,
  its phonetic representation included; the parts are encoded under `NS.<part>` keys.
- `-description` is `<NSPersonNameComponents: 0x…> {givenName = …, familyName = …, middleName = …, namePrefix = …, nameSuffix = …, nickname = … phoneticRepresentation = … }`,
  a part that is not set written `(null)` and the phonetic representation described the same way.

## What the port answers, and what iOS 6 does with them

The object is a plain value on the release. `NSPersonNameComponentsFormatter` is not carried, so nothing formats the parts.
