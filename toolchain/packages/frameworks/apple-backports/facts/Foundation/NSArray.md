# NSArray and NSDictionary, the URL API of iOS 11.0

Introduced in iOS 11.0: reading and writing a property list through a URL with
an error instead of a plain `nil`.

Source: Foundation of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372); the
current behaviour from the differential test against the host's Foundation
(`tests/backports/host/foundation11`). `NSDictionary` carries the same three
methods with the same shape, so both classes share this file.

| method | address in 11.0 |
|---|---|
| `-[NSArray writeToURL:error:]` | `0x181506f70` |
| `+[NSArray arrayWithContentsOfURL:error:]` | `0x1815069e4` |
| `-[NSArray initWithContentsOfURL:error:]` | `0x181506ac8` |
| `-[NSDictionary writeToURL:error:]` | `0x181521348` |
| `+[NSDictionary dictionaryWithContentsOfURL:error:]` | `0x1815214fc` |
| `-[NSDictionary initWithContentsOfURL:error:]` | `0x1815215e0` |

## Writing

1. The receiver is checked for being a property list.
2. The format is **XML** (`NSPropertyListXMLFormat_v1_0`, the constant `100`),
   unless the `NSWriteOldStylePropertyLists` default is set, which 11.0 reads
   from `NSUserDefaults` once and caches. The port always writes XML: the old
   style is a defaults switch of the desktop and nothing on iOS 6 sets it.
3. `+[NSPropertyListSerialization dataWithPropertyList:format:options:error:]`
   with no options.
4. `-[NSData writeToURL:options:error:]` with `NSDataWritingAtomic`.

Failures come out of those two calls unchanged:
- `3851` for a value that is not a property list. The SDK names that number
  `NSPropertyListWriteStreamError`, not `…WriteInvalidError`, which is `3852`.
- `518` for a URL whose scheme cannot be written to.
- `4` for a path whose folder does not exist.

For a value that is not a property list, the serializer of iOS 6 fails without
an error: it answers `nil`, leaves the error untouched, and only logs
`Property list invalid for format: 100 (…)`. On that release the port makes the
error itself. It checks the value the way the serializer does - strings, data,
dates and numbers pass, arrays and dictionaries are walked, and a dictionary's
keys must be strings - and fills in `NSCocoaErrorDomain` `3851` with the
serializer's own words in `NSDebugDescription`:
- `Property list invalid for format: 100 (property lists cannot contain objects of type '<type>')`
- `Property list invalid for format: 100 (property list dictionaries may only have keys which are CFStrings, not '<type>')`

Here `<type>` is CoreFoundation's name of the offending object's type, such as
`CFType` for an `NSObject` or `CFNumber` for a number. When the walk finds
nothing wrong but the serializer still failed silently, the error is `3851`
with no description. On a release whose serializer does report an error, that
error is passed on as it is.

## Reading

1. A `nil` URL answers `nil` and leaves the error alone.
2. The data is read with `-[NSData initWithContentsOfURL:options:error:]` and no
   options — 11.0 takes a string argument through
   `-initWithContentsOfFile:options:error:` instead, which the SDK's type does
   not allow the port to receive.
3. `+[NSPropertyListSerialization propertyListWithData:options:format:error:]`
   with no options.
4. The value is checked for being of the wanted kind.

`+…WithContentsOfURL:error:` is `allocWithZone:nil` and `-initWithContentsOfURL:error:`.

Errors: `260` for a file that is not there, `256` for a scheme that cannot be
read, and whatever the property list serializer raises for damaged data.

## Two departures from 11.0

- **A value of the wrong kind.** 11.0 answers `nil` and leaves the error as the
  serializer left it — often untouched, so the caller sees a `nil` with no
  reason. The current implementation answers `nil` with `NSCocoaErrorDomain`
  `259` (`NSFileReadCorruptFileError`) and
  `<url> did not contain a top-level array value` (or `dictionary`) in
  `NSDebugDescription`. An empty file reads the same way. The port implements
  the current behaviour: a caller that checks the error deserves one.
- **Mutability.** 11.0 returns the property list object itself, so
  `[[NSMutableArray alloc] initWithContentsOfURL:error:]` answers an immutable
  array. The current implementation answers a mutable one. The port builds the
  result with `-initWithArray:` (`-initWithDictionary:`), which gives the
  receiver's own kind and matches the current behaviour.
