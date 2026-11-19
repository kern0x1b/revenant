# Shadowed classes: a system class that a proxy completes

Some iOS 6 system classes exist but lack members that a later SDK declares, and Backports answers those members with a
proxy class `Revenant<Name>`. The library exports `_OBJC_CLASS_$_<Name>` as an alias of the proxy, so code that the
Backports library links against gets the proxy. An app image that the SDK linked binds the same symbol to the system
framework instead, so it gets the system class and not the proxy. `CASpringAnimation` is the case: QuartzCore on
iOS 6.1.3 has a `CASpringAnimation` without `initialVelocity` or `settlingDuration`.

A class that the device itself exports never gets a proxy, whatever the SDK's availability table says, except a
stranger: a private class that only shares the name. The generator reads the iOS 6.1.3 release's measured Objective-C
class inventory (name, exporting image, members) and does not fall back to another release's file or to an empty one:
without `dyld/6.1.3/classes_armv7.json` in the cache it stops and says so. It drops the class row from the skeleton when
the device has the class and one of these holds: the exporting image is a public framework (`/System/Library/Frameworks`),
whichever one the SDK puts the class in, or the exporting image is the private framework of the same name, or the device
class implements at least one member that the SDK declares for it. No table of equivalent images is kept: Foundation
classes that CoreFoundation exports, UIKit classes that QuartzCore exports and the like are public images and need no
entry, and the six `ImageCaptureCore` classes, which a private `ImageCapture` image exports, are the same classes because
the device implements 12 of the 20 members that the SDK declares for `ICDevice`, 14 of 21 for `ICCameraItem`, 6 of 14 for
`ICDeviceBrowser` and the like (measured). `SKOverlay` in StoreKit is the one stranger left: SkankKit's class of that name
has the superclass `SKLayer` and none of the 5 members of the SDK's, so it keeps its proxy; `cf_cast_test` names it as the
only class of the skeleton that the device also exports.

Of 5,523 class rows that the SDK declares and iOS has, the rule agrees with the earlier image table on every row that
the table accepted, and it additionally accepts rows that the table rejected (95; the ownership filter drops those rows for the frameworks that only name
the class; each one was not inspected). The generated skeleton drops the six `ImageCaptureCore` proxies, which no shipped
library compiled, because no Backports library carries `ImageCaptureCore`; an app that links that framework on 6.1.3 binds
no Backports export for it either way.

The reason is dynamic casts. Every object the system makes descends from the real class, so a Swift `as!` or an
Objective-C `isKindOfClass:` against a proxy can never succeed; the trap names the proxy, as in
`Could not cast value of type '__NSCFDictionary' to 'RevenantNSMutableDictionary'`. A proxy also hides the
`kCFNull` singleton, so QuartzCore's pointer comparison misses and sends a `CAAction` message to a stand-in. Members
that a later SDK added to an existing class live in a category on the real class instead. The generator's rule is
checked by `cf_cast_test` and by `alias_adoption_test`, which asserts that the device classes have no proxy export.

`frameworks/Backports/tools/shadowed-classes.txt` lists those classes, so a consumer knows which imports to move to
the proxy.

## Format

One line per class, after the `#` comment header:

    shadow <class> <proxy> <symbol>

For `CASpringAnimation` the file has:

    shadow CASpringAnimation RevenantCASpringAnimation _OBJC_CLASS_$_CASpringAnimation

- `<class>` is the system class name.
- `<proxy>` is `Revenant<class>`, the proxy class in `frameworks/Backports/src`.
- `<symbol>` is `_OBJC_CLASS_$_<class>`, the class symbol that an image binds.

The members of the proxy are in `frameworks/Backports/tools/lowered-members.txt` under `<proxy>`. The file lists no
members, so it stays short and does not repeat that file.

## Criterion

A class is listed when all three hold:

1. The iOS 6.0 release has the class. That is the class list of `frameworks/Backports/tools/device-members.txt`,
   which comes from the release's dyld cache inventory.
2. The proxy `Revenant<class>` implements members, which `lowered-members.txt` lists.
3. The Backports library lowers no member onto the system class itself. `lowered-members.txt` lists none under `<class>`.

Condition 3 means the library has not completed the system class, so a binding to it gets a class without the proxy's
members. A class that the library does complete is not listed.

The criterion is at class level. It does not check each member of the proxy against the system class. A class that
the library completes partly is not listed, even if a member of the proxy is still missing from the system class.

## What a consumer does

For each `shadow <class> <proxy> <symbol>` line, treat an import of `<symbol>` as unavailable on the device and rebind
it to the Backports library that exports `<symbol>`. Check the exporter from the library itself, with
`nm -gU <library> | grep <symbol>` and a strong `S` line. For `CASpringAnimation` it is
`libUIKitBackports.dylib`. Imports of classes that are not listed keep their current rule.

The rebind changes only the classes in the list. A class that is available on the device with all its members is
not moved.

The recompiler's translator is a consumer: with `BACKPORTS_DIR` it binds a class that the iOS 6 cache has to the system
library, and keeps the classes of this list on the Backports ([library mode](../../reference/recompiler/library-mode.md)).

## Regenerating and testing

    ./xmakew l -P . frameworks/Backports/tools/shadowed_classes.lua

The generator reads the proxy sources through `lowered-members.txt`, `device-members.txt` and the `src/` aliases:
`REVENANT_ALIAS(<class>)` and `.set _OBJC_CLASS_$_<class>,`. It needs no SDK.
`frameworks/Backports/tests/lowered_members_test.lua` fails when the committed file does not match the generated text.
It also fails when a listed class has no `GUARDED` entry in that test. A `GUARDED` entry names the function in the
proxy that answers for the system class and the selectors that the function checks, so a forwarding answer needs a
completeness check.

The file is not in the `.deb`. A consumer reads it from the repository checkout.
