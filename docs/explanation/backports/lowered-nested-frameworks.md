# Nested frameworks in the lowered overlay

A framework nested in another, such as MPSCore.framework inside MetalPerformanceShaders.framework, is reached by a
framework-style include of its parent's header. `MetalPerformanceShaders.h` imports `<MPSCore/MPSCore.h>`.

Clang resolves that include next to the including file. Under the overlay the includer is the copy the lowering
wrote, because `use-external-names` is on by default, so the lookup runs in the copied tree. The overlay copied only
the headers the lowering changed. MPSCore.h is unchanged, so the copied tree had no `Frameworks/MPSCore.framework`
and the lowered umbrella header failed with `'MPSCore/MPSCore.h' file not found`.

The overlay now copies every header of the frameworks nested under a framework whose Headers folder it maps
(`nested_headers_of_changed` in `toolchain/modules/apple/lowered.lua`). The copies hold the SDK's own text, so the
lowering is unchanged for them. `frameworks/Backports/tests/lowered_vfs_test.lua` asserts that MPSCore.h is copied.

Checked on the SDK 26.2 with the VFS alone, at armv7 iOS 6.0: the base overlay reports the error above, and the
overlay with the copies compiles an umbrella import with no diagnostic.
