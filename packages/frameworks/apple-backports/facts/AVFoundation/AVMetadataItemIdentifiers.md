# AVMetadataItem.dataType / .extendedLanguageTag / .identifier, iOS 8

Corpus rank 6, `AVMetadataItem.dataType` (+4 owners): `identifier`, `extendedLanguageTag` and their
`AVMutableMetadataItem` readwrite counterparts, plus the three class-side conversion methods.
`AVMetadataItem` itself has been real on iOS 6 since iOS 4.0 - these are new properties on an
existing, present class, not a new class.

## dataType

The value already exists on the item (`.value`, real and present since iOS 4.0); `dataType`
describes what kind of thing it is, which the value's own Objective-C class already answers: an
`NSString` is UTF-8, an `NSNumber` is one of the signed/unsigned integer or float widths its
`objCType` names, an `NSData` is sniffed for the JPEG/PNG/GIF/BMP magic bytes at its head and
otherwise called raw data. The values returned - `com.apple.metadata.datatype.UTF-8`,
`...raw-data`, `...JPEG`, `...int32`, and so on - are the release's own literal strings for
`kCMMetadataBaseDataType_UTF8` and the rest of `<CoreMedia/CMMetadata.h>`'s constants, read out of
`__cstring` in `CoreMedia` extracted from the armv7 shared cache of iOS 8.0 with
`modules/apple/dyld.lua`'s `extract`, not invented: iOS 6.1.3's own CoreMedia does not export these
names yet (checked first), so the earliest release that does was used. `AVMutableMetadataItem`
holds an explicit override when set and falls back to the same computed default otherwise.

## identifier

Documented as the keySpace and key joined; both are real, present properties since iOS 4.0. Built
as `"<keySpace>/<key>"`, the key turned into a string as-is if it is already one, as a decimal
string if it is an `NSNumber`, or as lowercase hex if it is `NSData` - the same three key classes
the header's own `identifierForKey:keySpace:` documentation names as convertible. The two
class-side conversions (`+identifierForKey:keySpace:`, and their inverses
`+keySpaceForIdentifier:`/`+keyForIdentifier:`) build and split the same string. `AVMutableMetadataItem`'s
setter parses `"<keySpace>/<key>"` and assigns the item's own real `key`/`keySpace` properties
directly, rather than keeping a separate cached string that could drift from them.

## extendedLanguageTag

The item's `locale` (real, present since iOS 4.0) already carries this in POSIX form (`en_US`);
`extendedLanguageTag` asks for the IETF BCP 47 form (`en-US`). The conversion applied is the
narrow one most locale identifiers already satisfy - underscores to hyphens and back - not the
full POSIX-to-BCP-47 algorithm (script and variant subtags, `@` extensions), a real, scoped
limitation for locales that use those.

## What is not carried

`+[AVMetadataItem metadataItemsFromArray:filteredByMetadataItemFilter:]`, `AVMetadataItemFilter`
(iOS 7), `+metadataItemsFromArray:filteredByIdentifier:` (iOS 8), `AVMetadataItem.startDate` and
`AVMetadataItemValueRequest` (iOS 9) are a different corpus rank and were not in scope for this
pass; they remain in `registry/AVFoundation/absent_AVFoundation.json` until taken up.

`+keyForIdentifier:` cannot recover an original key that was an `NSNumber` or `NSData`: the
identifier string carries only the decimal or hex rendering, and there is no way to tell from the
string alone which of `NSString`/`NSNumber`/`NSData` it came from, so the inverse always answers
an `NSString`. Stated here rather than silently returning the wrong type.
