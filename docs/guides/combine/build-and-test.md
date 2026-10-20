# Build and test Combine

## Build

Inside revenant, `frameworks/Combine/xmake.lua` requires `revenant@combine` with `sources = true`
and makes two targets of the revenant project for iOS (`./xmakew f -P . -p iphoneos -a armv7` at
the revenant top) from the installed tree: `Combine`, the one module, and `CombineHelpers`, the
C++ helper it imports. A target of another member links it with `add_deps("Combine")`.

Outside revenant, the legacy-iOS (armv7) build is taken through the toolchain as a package
dependency:

```lua
add_requires("revenant@combine", {alias = "combine"})
add_packages("combine")
```

## Test

`./xmakew build -P . CombineTests` compiles upstream's `Tests/OpenCombineTests` against the module
as one daemon, with the XCTest shim of `frameworks/Combine/tests/XCTest.swift`; the test list is
found by `frameworks/Combine/tools/discover.lua` and leaves out what `frameworks/Combine/tests/data/skip.txt`
names. With the project configured `--emulate=y`, `./xmakew emulate -P . -d iPhone4,1 -r 6.1.3 install`
and `./xmakew emulate -P . -d iPhone4,1 -r 6.1.3 run /usr/libexec/CombineTests` start it in the guest
(skill `emulator`), and its exit status is the verdict. `./xmakew test -P . CombineGenerated`
expands each gyb template with Revenant's gyb (`toolchain/modules/gyb`) and checks the `GENERATED-*`
source beside it is that expansion byte for byte.

The results of the run on iOS 6.1.3, and the tests it leaves out, are in
[test results](../../reference/combine/test-results.md).
