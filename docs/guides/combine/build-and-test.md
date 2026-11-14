# Build and test Combine

## Build

Combine is the package `revenant@combine`, built once from the patched OpenCombine tree: the one module `Combine`
and the C++ helper `CombineHelpers` it imports. Inside revenant, a target of another member takes it with
`add_packages("combine")`, as `frameworks/SwiftUI` does, and the component `frameworks/Combine` takes the upstream
tree from the same package for its tests.

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
(skill `emulator-session`), and its exit status is the verdict. `./xmakew test -P . CombineGenerated`
expands each gyb template with Revenant's gyb (`toolchain/modules/gyb`) and checks the `GENERATED-*`
source beside it is that expansion byte for byte.

The results of the run on iOS 6.1.3, and the tests it leaves out, are in
[test results](../../reference/combine/test-results.md).

## Test the helper and the link

`libCombine.a` calls the locks and the identifier counter of the C++ helper `libCombineHelpers.a`, and
a link that names no archive finds the helper only through the autolink records the objects carry
(reference: [the package](../../reference/combine/package.md), "How a link finds the archives"). The
component has its own configuration and a target for each part:

```
./xmakew f -P . -p iphoneos -a armv7 --component=Combine -y
./xmakew build -P . CombineHelpersTests
./xmakew test -P . 'CombineHelpers/*'
```

`CombineHelpersTests` is `frameworks/Combine/tests/helpers/main.swift` linked the way Telegram's Bazel link
links: it imports Combine and the C module, takes no package, and puts only the package's `lib` folder on
`-L`, so `-lCombine` and `-lCombineHelpers` come from the objects alone. The two tests of the `CombineHelpers`
target are:

- `autolink`: the object records `-lCombine` and `-lCombineHelpers`, the target's link line names neither, the linked
  binary defines the helper's functions, and no `_opencombine_*` symbol is undefined in it.
- `locks`: the helper's source, compiled with the host's clang into an archive, and the same `main.swift` compiled
  and linked on the host: the identifier counter counts by one and leaves no gap across 8 threads, the lock and the
  recursive lock lose no increment across 8 threads, the recursive lock is entered 32 deep by its owner and blocks
  another thread until every level is released, `stop in debugger` raises `SIGTRAP`, and a Combine pipeline delivers
  its values. The host locks with `os_unfair_lock`, so the checks of the iOS 6 path, a lock taken twice by its owner
  and a lock released by a thread that does not hold it, each ending the process with `SIGABRT`, run only below iOS 10,
  that is on the device.

On the device the binary and the Swift runtime dylibs it names go into one folder of the phone, and the run sets
`DYLD_LIBRARY_PATH` to it, because the binary is not packaged (a daemon of this shape is refused by the import
check, which wants the Backports libraries before the runtime in a link line that the `daemon` rule does not order).
The Backports libraries the binary links, `libFoundationBackports.dylib`, `libCoreFoundationBackports.dylib` and
`libSystemBackports.dylib`, come from the same build, because the binary binds to the classes that build exports:

```
./xmakew device -P . claim
./xmakew device -P . run "mkdir -p /var/root/revenant-scratch/$REVENANT_DEVICE_HOLDER/combine-helpers"
./xmakew l -P . frameworks/SwiftUI/tools/device.lua copy build/iphoneos/armv7/release/CombineHelpersTests /var/root/revenant-scratch/$REVENANT_DEVICE_HOLDER/combine-helpers/CombineHelpersTests
./xmakew device -P . run "cd /var/root/revenant-scratch/$REVENANT_DEVICE_HOLDER/combine-helpers && DYLD_LIBRARY_PATH=/var/root/revenant-scratch/$REVENANT_DEVICE_HOLDER/combine-helpers ./CombineHelpersTests"
./xmakew device -P . release
```

after the dylibs (`otool -L` of the binary lists them) are copied the same way. The folder is the holder's scratch
folder, which the release above erases, so nothing stays on the phone. The run ends with
`combinehelpers: every check held` and exit status 0. With several phones attached, `-d NAME` picks one, as the
skill `device-session` says.
