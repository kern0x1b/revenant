# Adding a module to the React Native host

This is the order for one module of [the coverage table](../../reference/react-native/coverage.md): an Expo package, a community
native library, or a part of the React Native core. A module is done when it is built from its own sources, a probe on the phone
shows it working, and its row says `real`. A name-only stub, a plain-view replacement or a staged copy of a source file is not
done; it is a gap, and the row says `stub` or `partial` with the reason.

## 1. Take the row

Pick a row whose status is `missing`, `stub` or `evaluate`, and say in the thread which one you took. Read its note: it names what
iOS 6 lacks. Write down which system API the module needs and the first iOS release that has it
(`xcrun` is not needed: the iPhoneOS 26.2 SDK headers carry `API_AVAILABLE`, and `docs/reference/backports` lists what the backports
already cover).

## 2. Get the sources as a package

Third-party code enters the repository as a package, never as copied files. Expo and community packages are npm packages:
`packages/<first letter>/<name>/xmake.lua`, as `packages/r/react-native-screens` is, pinned to the version of
`expo/bundledNativeModules.json` of the SDK. Changes to the module's sources are patch files in the package's `patches` folder,
named for what they fix, listed with `add_patches` and their sha256. When a patch is about a system service that is missing before
some iOS release, look first whether a backport (`frameworks/Backports`) can supply the service: that closes the gap for every module
at once, which a patch does not.

## 3. Build it as the real module

Until the host build is a component of this repository, it lives in the spike (`paseo-app/rn-spike`), and you build it in your
own folder as [the isolated build](isolated-build.md) says. A module is added to its build
with `RN_EXPO_REAL=<package>` (Expo packages) or the `PODS` list of the build script (community libraries). Build, and collect all
errors of the module at once, not one by one. Each error is one of:

| Error | Close it with |
| --- | --- |
| a type, class or constant that iOS 6 lacks | a backport, or a patch that guards its use |
| `@available(iOS N, ...)` or `#available` | nothing, when the guarded branch never runs on iOS 6; the weak-import audit records it |
| an iOS 14 or later Swift type (SwiftUI, PHPicker, UTType) | the SwiftUI backport, a backport of the type, or a patch that removes the feature and names it in the note |
| a clash of declarations between packages | one patch in one package |
| `@import` or modules with modules disabled | a patch to `#import` |

Do not skip a file from the build, stage a rewritten copy, or register a name-only module to make the application load. If the
whole module cannot work on iOS 6, its row becomes `impossible` with the release that introduced the service, and the module
answers as the platform would without the service (an unavailable result, not a crash).

## 4. Check it on the phone

The check is a probe: a small Expo application that calls the module and prints what it got. Export it with
`frameworks/ReactNative/tools/export_bundle.lua`, and put it on the claimed phone as `/var/tmp/real.js` with the host built with the
module. The probe prints one line per call with the prefix `CHECK`, which shows in `/var/tmp/rnhost.log` (enabled by
`touch /var/tmp/rnhost.log.on`):

```js
import { requireNativeModule } from "expo-modules-core";

const module = requireNativeModule("ExpoClipboard");
console.log("CHECK constants", JSON.stringify(module.constants ?? {}));
module.setStringAsync("probe").then(() => module.getStringAsync()).then((value) => console.log("CHECK roundtrip", value));
```

A check passes when each call returns the value the module's documentation promises, or the error it documents for a missing
service, and the host is still running afterwards. Add a screenshot of anything the module draws or shows
(`frameworks/ReactNative/tools/touch.lua --before ... --after ...` drives the screen). A module that only compiles is
`verified: build`, not `phone`.

## 5. Record it

Change the module's row in `frameworks/ReactNative/src/coverage.json` (status, checked, and a note that says what was done or what is
left), then run `./xmakew l -P . frameworks/ReactNative/tools/coverage.lua` and commit both files. The test `coverage_test` fails when
the document and the data differ.

## 6. Land it

Branch `work/rn-<topic>` from `origin/main`. Commit first and run `./xmakew l -P . tools/prepush.lua` after: its layout, comments and
documented-command checks read only committed files. Packages are installed and tested in a private cache
(`tools/private_cache.lua`, `docs/guides/machine.md`), never in the shared `.cache`. Report the tip, the probe lines and the
screenshot.
