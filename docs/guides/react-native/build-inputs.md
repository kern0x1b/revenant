# Making the build inputs of the React Native host

The host build reads a folder of inputs, `build/`, that used to be made by hand and by scripts of the spike project
(`paseo-app/rn-spike`). `frameworks/ReactNative/tools/inputs.lua` makes them from the revenant packages `react-native`,
`react-native-codegen`, `react-native-nitro-modules`, `expo-*` and the application's `node_modules`. One command makes all of
them.

## Make inputs

```sh
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua make <project> --only codegen,rn-codegen
```

`<project>` is the folder whose `build/` receives the inputs. The application is read from `build/ref/paseo`, a link to the
application's checkout, which is read only. Options:

- `--only a,b` makes the named inputs. Without it, `make` makes every input in the order of `INPUTS`, where `expo-jsi` and
  `expo-pods` come before `expo-core`, whose Swift header imports them.
- `--build DIR` names the output folder, `--app DIR` the application (default `build/ref/paseo`), `--react-native DIR` a
  `react-native` source tree in place of the revenant package.
- `--real p,q` replaces the default Expo packages with the named ones, on top of the base the spike always builds: the parity
  mode described below.

The Expo inputs (`expo-pods`, `expo-src`, `expo-core`) take one list of packages, in two modes:

- Without `--real`, the packages are `expo` and the Expo SDK packages that `frameworks/ReactNative/src/coverage.json` marks
  `real` or `partial` and that have native code. `expo-modules-core` is left out, because `expo-core` builds it. Stubs, missing
  packages and js-only packages are not in the list. This is the default: 18 packages at the time of writing.
- With `--real`, the list is the spike's configuration (`RN_EXPO_REAL`) on top of its base. The parity comparison below uses it:

```sh
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua make <project> --real expo-audio,expo-camera,expo-clipboard,expo-document-picker,expo-file-system,expo-font,expo-haptics,expo-image,expo-image-manipulator,expo-image-picker,expo-router,expo-sharing,expo-splash-screen,expo-sqlite,expo-symbols
```

The first run installs the packages into the revenant store of the checkout, the `REVENANT_CACHE` of the worktree. In a linked
worktree `REVENANT_CACHE` must be set; the tool does not fall back to the main checkout's cache. Each input folder is emptied
before it is written, so a run replaces the previous output of that input only.

## Compare with the spike

```sh
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua compare <reference build> <built build> --only codegen
```

`compare` lists the entries of each input in both folders and reports the entries present on one side only, the entries of
different kinds, the files whose content differs and the links whose targets differ. The built path of a file is replaced by
the reference path before the hash is taken, so a folder made elsewhere is comparable. `--rewrite BUILT=REFERENCE` replaces one
more string on the built side.

The spike's build read its packages from the shared cache of the checkout, and a worktree's build reads its private cache. The
store paths in `expo-jsi` (`libcxx.rsp`) are then rewritten to the shared cache:

```sh
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua compare paseo-app/build <project>/build --only expo-jsi \
    --rewrite "<worktree>/.cache-private=<checkout>/.cache"
```

The comparison exits with an error when an input differs, and prints `same (N entries)` for each input that does not.

## Status

| Input | State |
| --- | --- |
| `codegen` | Made. The two files that name the application and `react-native` by a path relative to the output folder differ from the spike only in that relative path, because the output folder sits elsewhere and `react-native` comes from the store. |
| `rn-codegen` | Made. Identical to the spike (171 entries). |
| `rn-src` | A link to the `react-native` package sources of the store. The spike's link names another install of the same version (`rn-modules`), whose `ReactCommon/jsc/JSCRuntime.cpp` differs, so the link stays a difference. |
| `rn-headers` | Made from the podspec rules. Identical to the spike: 761 entries, including the Swift header of keyboard. The curated `react.modulemap` list (109 names) is data in `tools/data/expo-core-react-headers.txt`, not derived from a rule. |
| `lib-headers` | Made. Identical to the spike (64 entries). |
| `expo-jsi` | Made. Identical to the spike (6 entries) once the private cache is rewritten to the shared cache: `libcxx.rsp` names the store the build used. |
| `expo-pods` | Made. Identical to the spike (43 entries) in the parity mode (`--real`); the default mode makes the pods of the coverage list. |
| `expo-core` | Made. `swift-header`, the module maps, `include/ExpoModulesCore` and `react.modulemap` are identical to the spike. `flags.rsp` names the `react-native` root as the store package, where the spike names the application's copy in `node_modules`. `ExpoModulesProvider.swift` and `bridging.h` follow the packages of the mode (the stubs and the real modules, as the spike's `on_load` writes them); the spike's copies on disk predate its list. Every other entry is identical. |
| `expo-src` | Made in both modes; `expo-file-system` is `partial` in the coverage, so both lists include it. The spike's folder on disk has three files and no copies of the `expo-file-system` sources, while the spike's `on_load` stages `FileSystemDownload.swift`, `FileSystemFileHandle.swift` and `FileSystemModule.swift` as copies whenever `expo-file-system` is real (`EXPO_REWRITE`). The tool makes them too: in the parity comparison they are the only differences, and the other three entries are identical. The default mode leaves out the sources of the stubs (document picker, image picker, SQLite). |
| `nitro` | Made. `flags.rsp` names the `react-native` root as the store package, where the spike names the application's copy in `node_modules`. Otherwise identical. |
| `unistyles` | Made, including `swift-header`, which is identical to the spike. `flags.rsp` names the `react-native` root as the store package, where the spike names the application's copy in `node_modules`. The two copies differ (`ReactCommon/jsc/JSCRuntime.cpp`), so this stays a difference. |
| `keyboard` | Made, including `react_native_keyboard_controller-Swift.h`. Identical to the spike (5 entries). `prefix.h` carries the React imports that the Swift header needs and the spike got from the React clang module. |
| `screens` | Made. Identical to the spike (2 entries). |
| `app-assets` | Made from the application's Expo configuration (`npx expo config --type public --json`, the one `app_config.lua` reads) and the images it names: the icon, and the image of `expo-splash-screen` with its `imageWidth` and `backgroundColor`. Identical to the spike (6 entries). The icon sizes (57, 114), the launch image canvases (320×480, 640×960) and the iOS 6 keys of `Info.plist` (`MinimumOSVersion` 6.0, `armv7`) are fixed in the tool, as they are in the spike. `CFBundleName` is the host `RNHost`; `CFBundleDisplayName` is the configuration's `name`. |

The Swift headers are made by the tool through `swift_header`, which compiles the Swift targets with the spike's flags in a probe
project under the private cache. The probe links the checkout's `toolchain` folder, because the swift-runtime recipe reads its
overlay from the project root.

Ordering: every sort in the tool is byte order (`byte_less`), not the locale's. `compare --rewrite BUILT=REFERENCE` is repeatable,
and each pair maps a path that differs only by where a build was made (the private cache, the parity build root).
