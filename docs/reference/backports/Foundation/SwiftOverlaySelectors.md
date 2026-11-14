# The private selectors of the Swift Foundation overlay on iOS 6

The Foundation overlay of the Swift toolchain (`libswiftFoundation.dylib`, the arm64 image a recompiled library carries as a
guest) and the standard library (`libswiftCore.dylib`) use selectors that no SDK header declares. This page is the table of them
for the overlays the recompiler has been run with, which of them the iOS 6.1.3 release has, who supplies each, and what is
measured. The overlays are the Swift 5.0 back-deployment one of the Xcode toolchain, the one of the repository's older
`libs-old` and the one of the iOS 27.2 SDK; the private selectors are the same in all three.

## How the table was made

1. Every selector name in `__TEXT,__objc_methname` of each overlay image (881 names in the nine images of the reCAPTCHA-style
   fixture), minus the names that the images define in their own method lists (386), leaves the names that the images send and do
   not define: 200 of them are not in the selector list of the iOS 6.1.3 dyld cache
   (`dyld/6.1.3/selectors_armv7.txt`, 113 713 selectors). All but two of those are public API of a later SDK (the URL components,
   the calendar and date members, the percent encoding, the markdown and intent types), which the Backports lower by
   `lowered-members.txt` and which this page does not list.
2. The private ones come from the overlay's own categories, which `otool -ov` lists for the image (`__CATEGORY_<class>_$_Foundation`
   for Swift extensions of an Objective-C class and `__OBJC_$_CATEGORY_<class>_$_SwiftAdditions` for the Objective-C ones), and
   from the two names of the standard library that no image defines.

## The table

| Selector | Receiver | Defined by | iOS 6.1.3 | Supplied by | Measured on the iPhone 4S (2026-11-15) |
|---|---|---|---|---|---|
| `-__swift_objectForKeyedSubscript:` | `NSDictionary`, `NSMutableDictionary` | overlay category (Swift extension) | absent | overlay; Backports `NSDictionary+SwiftOverlay.m` for both | answered on both |
| `-__swift_setObject:forKeyedSubscript:` | `NSMutableDictionary` | overlay category | absent | overlay; Backports for `NSMutableDictionary` | answered after the Backports category; before it, `dictionary[key] = value` of a Swift `NSMutableDictionary` stopped with `unrecognized selector` |
| `-__swiftInitWithDictionary_NSDictionary:` | `NSDictionary` | overlay category | absent | overlay; Backports | answered |
| `+_swift_checkClassAndWarnForKeyedArchiving:operation:` | `NSKeyedUnarchiver` | overlay category | absent | overlay | answered |
| `+_swift_bundleWithExecutablePath:` | `NSBundle` | overlay Objective-C category `SwiftAdditions` | absent | overlay | answered |
| `-newTaggedNSStringWithASCIIBytes_:length_:` | `NSObject`, `NSString` | overlay category on `NSObject`; Backports on `NSString` | absent | Backports `NSString+TaggedASCII.m` ([why nil](TaggedASCIIString.md)) | answered |
| `+__old_unswizzled_automaticallyNotifiesObserversForKey:`, `+__old_unswizzled_keyPathsForValuesAffectingValueForKey:` | `NSObject` | overlay category | absent | overlay | answered |
| `+_swift_bundleForClass:`, `+newIndirectTaggedNSStringWithConstantNullTerminatedASCIIBytes_:length_:`, `-isNSCFConstantString__`, `-isNSObject__`, `-_noteAssociatedObjects`, `-_setWeaklyReferenced`, `-_kvcKeyPathStringPtr`, `+_noteProcessHasUsedKVOSwiftOverlay`, `-returnsAutoreleased:` | strings of the `libswiftCore.dylib` method-name section | the standard library's runtime half | absent (the first two), or defined by the runtime itself | not supplied | no step of the fixtures has stopped on one (the steps of the libgenerics and reCAPTCHA-style fixtures, among them strings of several lengths and weak references); whether the runtime ever sends one to a system object was not traced. Not added: a nil-answering method added for a selector that the runtime guards with `respondsToSelector:` would turn a skipped path into a taken one |
| `-_fastCStringContents:`, `-_fastCharacterContents`, `-_tryRetain`, `-_isDeallocating`, `-_copyDescription`, `-_cfTypeID`, `-_indexOfRangeContainingIndex:` | `NSString`, `NSObject` | system | present | system | not needed |

The overlay has no private selector for `NSArray`, `NSSet`, `NSString`, `NSData` or `NSOrderedSet`: their Swift subscripts and
bridging use public members (`objectAtIndexedSubscript:` and `setObject:atIndexedSubscript:` are in the 6.1.3 release, measured by
`respondsToSelector:`), so only the two dictionary classes need a category of the Backports.

## Why the Backports carry the dictionary selectors although the overlay defines them

A translated library carries the overlay's categories, and libobjc attaches them to the class that the category names. With
`BACKPORTS_DIR` the library is linked with the Backports before the system frameworks, and the Backports export a proxy class for
about sixty Foundation classes, `NSMutableDictionary` among them, as `_OBJC_CLASS_$_NSMutableDictionary`. The category's class
pointer is then the proxy and not the system class, so the methods land on a class that no `NSMutableDictionary` instance
belongs to (the probe saw `-[__NSDictionaryM __swift_setObject:forKeyedSubscript:]: unrecognized selector`, and
`+instancesRespondToSelector:` answered no on the system class while the categories of `NSDictionary`, `NSKeyedUnarchiver`,
`NSObject` and `NSBundle`, whose classes have no proxy, answered yes). The category of the Backports is attached by `attach.c` to the
system class, so the selector is answered whichever class the library bound.

A source that implements a class takes the class out of the generated skeleton, and with it the export of
`_OBJC_CLASS_$_<class>`. The category of `NSMutableDictionary` did that, and a library translated before (`ABFixture.dylib`
of the probe) stopped at load with `Symbol not found: _OBJC_CLASS_$_NSMutableDictionary` (measured). `NSMutableDictionaryAlias.m`
declares the proxy explicitly, so the export stays.

## Tests

`frameworks/Backports/tests/Foundation/swift_overlay_dictionary_test.m` runs the categories on the host (a mutable dictionary
answers the setter, sixteen keys are set, a nil value removes a key, the getter answers for both classes, the initialiser copies a
dictionary); with `--negative` it expects the wrong count after the removal and must fail.
`frameworks/Backports/tests/alias_adoption_test.lua` checks that the built `libFoundationBackports.dylib` still exports
`_OBJC_CLASS_$_NSMutableDictionary`.
