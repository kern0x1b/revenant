# Shadowed classes: a system class that a proxy completes

Some iOS 6 system classes exist but lack members that a later SDK declares, and Backports answers those members with a
proxy class `Revenant<Name>`. The library exports `_OBJC_CLASS_$_<Name>` as an alias of the proxy, so code that the
Backports library links against gets the proxy. An app image that the SDK linked binds the same symbol to the system
framework instead, so it gets the system class and not the proxy. `CASpringAnimation` is the case: QuartzCore on
iOS 6.1.3 has a `CASpringAnimation` without `initialVelocity` or `settlingDuration`.

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

## Regenerating and testing

    ./xmakew l -P . frameworks/Backports/tools/shadowed_classes.lua

The generator reads the proxy sources through `lowered-members.txt`, `device-members.txt` and the `src/` aliases:
`REVENANT_ALIAS(<class>)` and `.set _OBJC_CLASS_$_<class>,`. It needs no SDK.
`frameworks/Backports/tests/lowered_members_test.lua` fails when the committed file does not match the generated text.
It also fails when a listed class has no `GUARDED` entry in that test. A `GUARDED` entry names the function in the
proxy that answers for the system class and the selectors that the function checks, so a forwarding answer needs a
completeness check.

The file is not in the `.deb`. A consumer reads it from the repository checkout.
