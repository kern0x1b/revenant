# Backports

Lists the iOS SDK members that the minimum deployment target lacks, emits a skeleton that fails loudly for each one `src/` does not implement, and counts how many are implemented.

## Scope

`backports_min_ios` (xmake option, default `6.0`) is the oldest iOS the build supports. In scope: a member introduced after it, and every member of a framework absent at it. A framework's introduction is approximated as the lowest introduction version among its annotated members.

## Facts

- ObjC and C: the umbrella header is run through `clang -Xclang -ast-dump` as text and streamed. `AvailabilityAttr` gives the introduction.
- Swift: `swift-api-digester -dump-sdk -swift-only` writes JSON, with one module cache shared by all frameworks.
- Each framework is one TSV in `build/generated/backports/cache/<sdk version>-<generator digest>/`. Four shards run in parallel under `/bin/sh`.

## Skeleton

`build/generated/backports/skeleton/` holds `revenant_backports.h`, `registrar.m`, and per framework `<N>.m` and `<N>.c`.

- Each in-scope member gets a stub that aborts with its name, for example `not implemented: -[NSUUID UUIDString]`. The skeleton does not read `src/`: a stub is inert wherever `src/` implements its member.
- ObjC methods and properties are added with `class_addMethod` only when the class does not already respond to the selector, so the system's implementation wins, as in `attach.c`. Missing classes are created first, only when `objc_getClass` finds none, so a class `src/` implements is never created twice.
- C and Swift stubs are weak definitions bound to the mangled symbol, so the strong definition in `src/` wins at link time within a library.

## Implemented count

The implemented members are the symbols of the objects that `src/<Framework>` compiles to, read from `build/.objs` with `nm` (classes, C functions, global variables) and the same `nm` listing for methods (with their class or category and selector). A property counts when its getter is implemented. Swift members are never counted as implemented. The clang AST was the first source of these keys; reading it cost hours on each cold build.

## Commands

- `./xmakew l -P . frameworks/Backports/tools/generate.lua`: facts and skeleton, cached per module.
- `./xmakew l -P . frameworks/Backports/tools/exports.lua [libdir] [report]`: after a build, reads the objects in `build/.objs` and the dylibs in `build/iphoneos/armv7/release` once each, checks every key of the objects against them, and writes `exports.txt` (per kind: implemented, exported once, missing, duplicated, not public; then the missing, duplicated and not public lines) and `status.txt` (`implemented X of Y` per framework) beside `report`. It fails when a public symbol or method is missing, or when two libraries export the same class, function, global or method.
- `./xmakew l -P . frameworks/Backports/tests/backports_test.lua`: fixture test.
- `./xmakew f -P . -p iphoneos -a armv7 --component=Backports` then `./xmakew build -P . FoundationBackports`: one shared library per library of the former package, `lib<Name>.dylib` with its install name under `/usr/lib/revenant/org.revenant.backports`. Each compiles `src/<Framework>`, `src/attach.c` and the skeleton of its framework, which configure generates; `backports_min_ios` is the only minimum, with no bands. The component option configures only this component and what it needs, and the build reads the iOS 26.2 SDK, so the sources compile against the headers they are written for.
- `REVENANT_GEN_SDK=<iPhoneOS SDK folder>` overrides the SDK the toolchain resolves.

## Public symbols

A key is public when the SDK both declares it and exports it: a class, C function, global or method declared in a framework's headers (from the clang AST, as the facts are), and for classes, functions and globals, also exported by a framework's `.tbd` (`tools/public.lua` scans each framework's `.tbd` for the names the headers declare). Methods are public through the headers alone. A key that is not public is counted and does not fail the check, and each class that is not public is listed.

`__NSConcreteUUID` is the one class the report lists as not public among the Foundation keys of the objects. The iOS 26.2 SDK's `Foundation.tbd` exports `_OBJC_CLASS_$___NSConcreteUUID`, but no Foundation header declares it, so it is not a declared symbol. The iOS 6.1.3 shared cache (read with `toolchain/modules/apple/dyld.lua`, `exported_by`) does not export it from Foundation, while it exports `NSUUID` and `NSTimer`; the class exists there only in Objective-C metadata, as a private class. An iOS 6 target never exported it, so the backport owes no export for it.

Methods of a `Revenant<Name>` proxy count as methods of `Name` when the library also exports `_OBJC_CLASS_$_<Name>`: the alias makes the proxy the class at run time (`revenant_alias.h`).

Methods are read from the libraries with `toolchain/modules/apple/objc.lua` (`binary_inventory`), which folds categories into their class, and from the objects with `nm`, which lists each method implementation as `-[Class sel]` or `+[Class sel]`. The objects are read once, in batches, for both reports.

## Limits

Swift types, variables and protocols are counted but not stubbed. Protocol objects and `_OBJC_CLASS_$_` class symbols are not emitted, so an app that links an absent class does not link yet. C global variables are not stubbed. Subframeworks and enum constants are excluded. ObjC type encodings are empty.

## Open gaps

The Swift overlays below are built as targets of this component, and each builds only for an iOS its backport reaches. Below that release the build refuses, and the wrapper package refuses on load, with "not yet backported". None of these is a supported minimum: each closes when its backport makes it build at iOS 6.

- `swiftRealityFoundation` and `swiftRealityKit` below iOS 8: they load SceneKit, and the SceneKit members they import (`SCNHitTestResult`, `-[SCNView hitTest:options:]`, `+[SCNNode nodeWithGeometry:]`) are not backported yet. RealityKit's UIKit part is open too. [RealityFoundation below iOS 8](../../docs/reference/backports/RealityFoundation/SceneKit.md) says what brings them back.
- `swiftNetwork` below iOS 12: its C seam (`src/Network/seam`) declares `nw_interface_t` and the other `nw_*` types of the Network framework, which iOS 6 lacks. Those declarations need backports for iOS 6 before the overlay can compile there.
