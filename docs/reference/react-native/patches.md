# React Native patches: spike against packages

The spike (`paseo-app/rn-spike/patches/`) kept copies of the iOS 6 patches. The packages in
`packages/` hold the same patches as recipe inputs, with sha256 values checked by the package manager. This
table records, file by file, whether the two sets agree and which one the spike build actually uses.

| Spike patch | Package patch | Result |
| --- | --- | --- |
| `ios6-32bit.patch` | `packages/r/react-native/patches/ios6-32bit.patch` | Same hunks; the spike copy carries a header comment and an `a/node_modules/react-native/` prefix. |
| `ios6-nil-attributed-text.patch` | `packages/r/react-native/patches/ios6-nil-attributed-text.patch` | Same hunks. |
| `ios6-weak-guards.patch` | `packages/r/react-native/patches/ios6-weak-guards.patch` | Same hunks. |
| `jsi-public-destructors.patch` | `packages/r/react-native/patches/jsi-public-destructors.patch` | Same hunks; path prefix only. |
| `rn-0.86.3-websocket-socketid.patch` | `packages/r/react-native/patches/rn-0.86.3-websocket-socketid.patch` | Byte-identical. |
| (none) | `packages/r/react-native/patches/ios6-32bit-image-size.patch` | Package only, newer: the `RCTImageUtils.mm` hunk, split out of `ios6-32bit`. The spike's `build/rn-src/Libraries/Image/RCTImageUtils.mm` contains it. |
| (none) | `packages/r/react-native/patches/jsc-runtime-context-accessor.patch` | Package only, newer: `RNJscRuntimeContext`. The spike's `build/rn-src/ReactCommon/jsc/JSCRuntime.cpp` contains it. |
| `native-libs-ios6-32bit.patch` (webview and reanimated hunks) | `packages/r/react-native-webview/patches/ios6-32bit.patch`, `packages/r/react-native-reanimated/patches/ios6-32bit.patch` | Same hunks, split per package. |
| `worklets-jsc.patch` | `packages/r/react-native-worklets/patches/worklets-jsc.patch` | Same hunks; path prefix only. |
| `expo-fabric-view-swift-base.patch` | `packages/e/expo-modules-core/patches/expo-fabric-view-swift-base.patch` | Same hunks; path prefix only. |
| `expo-viewmodulewrapper-ios6.patch` | `packages/e/expo-modules-core/patches/expo-viewmodulewrapper-ios6.patch` | Package newer: adds an `NSLog` error line and blank lines. The spike's `build/ref/paseo/node_modules/expo-modules-core/ios/Fabric/ExpoFabricViewObjC.mm` contains the `NSLog`, so the spike builds the package version. |

The spike's own `patches/` directory is therefore stale. The spike builds from `build/rn-src` and `build/ref`, which
already carry the package set. Every sha256 in the recipes matches its file in `packages/`. No spike patch is missing
from a package, so nothing was copied into a package.
