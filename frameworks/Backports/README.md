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

The implemented members are the symbols of the objects that `src/<Framework>` compiles to, read from `build/.objs` with `nm` (classes, C functions, global variables) and `otool -ov` (methods, with their class or category and selector). A property counts when its getter is implemented. Swift members are never counted as implemented. The clang AST was the first source of these keys; reading it cost hours on each cold build.

## Commands

- `./xmakew l -P . frameworks/Backports/tools/generate.lua`: facts and skeleton, cached per module.
- `./xmakew l -P . frameworks/Backports/tools/status.lua`: `implemented X of Y` per framework, after a build.
- `./xmakew l -P . frameworks/Backports/tools/exports.lua [libdir] [report]`: checks every key of the objects against the dylibs in `build/iphoneos/armv7/release`, and lists the keys no library exports (missing) and those two or more export (duplicated).
- `./xmakew l -P . frameworks/Backports/tests/backports_test.lua`: fixture test.
- `./xmakew f -P . -p iphoneos -a armv7 --component=Backports` then `./xmakew build -P . FoundationBackports`: one shared library per library of the former package, `lib<Name>.dylib` with its install name under `/usr/lib/revenant/org.revenant.apple-backports`. Each compiles `src/<Framework>`, `src/attach.c` and the skeleton of its framework, which configure generates; `backports_min_ios` is the only minimum, with no bands. The component option configures only this component and what it needs, and the build reads the iOS 26.2 SDK, so the sources compile against the headers they are written for.
- `REVENANT_GEN_SDK=<iPhoneOS SDK folder>` overrides the SDK the toolchain resolves.

## Limits

Swift types, variables and protocols are counted but not stubbed. Protocol objects and `_OBJC_CLASS_$_` class symbols are not emitted, so an app that links an absent class does not link yet. C global variables are not stubbed. Subframeworks and enum constants are excluded. ObjC type encodings are empty.
