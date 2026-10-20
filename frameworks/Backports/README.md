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

- Each in-scope member not implemented by `src/` gets a stub that aborts with its name, for example `not implemented: -[NSUUID UUIDString]`.
- ObjC methods and properties are added with `class_addMethod` only when the class does not already respond to the selector, so the system's implementation wins, as in `attach.c`. Missing classes are created first.
- C and Swift stubs are weak definitions bound to the mangled symbol. Whether the system's definition wins at link time is not measured yet.

## Implemented count

`src/**.m` and `src/**.c` are read through the clang AST and keyed by file content hash and SDK version under `build/generated/backports/implemented/`. Swift members are never counted as implemented.

## Commands

- `./xmakew l -P . frameworks/Backports/tools/generate.lua`: facts and skeleton, cached per module.
- `./xmakew l -P . frameworks/Backports/tools/status.lua`: `implemented X of Y` per framework.
- `./xmakew l -P . frameworks/Backports/tests/backports_test.lua`: fixture test.
- `./xmakew f -P . -p iphoneos -a armv7` then `./xmakew build -P . FoundationBackports`: one shared library per library of the former package, `lib<Name>.dylib` with its install name under `/usr/lib/revenant/org.revenant.apple-backports`. Each compiles `src/<Framework>`, `src/attach.c` and the skeleton of its framework, which configure generates; `backports_min_ios` is the only minimum, with no bands.
- `REVENANT_GEN_SDK=<iPhoneOS SDK folder>` overrides the SDK the toolchain resolves.

## Limits

Swift types, variables and protocols are counted but not stubbed. Protocol objects and `_OBJC_CLASS_$_` class symbols are not emitted, so an app that links an absent class does not link yet. C global variables are not stubbed. Subframeworks and enum constants are excluded. ObjC type encodings are empty.
