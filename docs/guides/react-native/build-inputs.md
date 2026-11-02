# Making the build inputs of the React Native host

The host build reads a folder of inputs, `build/`, that used to be made by hand and by scripts of the spike project
(`paseo-app/rn-spike`). `frameworks/ReactNative/tools/inputs.lua` makes them from the revenant packages `react-native`,
`react-native-codegen`, `react-native-nitro-modules`, `expo-*` and the application's `node_modules`, with one command per
input set.

## Make inputs

```sh
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua make <project> --only codegen,rn-codegen
```

`<project>` is the folder whose `build/` receives the inputs. The application is read from `build/ref/paseo`, a link to the
application's checkout, which is read only. Options:

- `--only a,b` makes the named inputs. Without it, `make` makes every input in order and stops at the first one that is not
  generated yet.
- `--build DIR` names the output folder, `--app DIR` the application (default `build/ref/paseo`), `--react-native DIR` a
  `react-native` source tree in place of the revenant package.
- `--real p,q` lists the Expo packages built as real modules. The Expo inputs without it use the stubs.

The expo-pods inputs need the real packages of the spike's configuration, and so does expo-src:

```sh
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua make <project> --only expo-pods \
    --real expo-audio,expo-camera,expo-clipboard,expo-document-picker,expo-file-system,expo-font,expo-haptics,expo-image,expo-image-manipulator,expo-image-picker,expo-router,expo-sharing,expo-splash-screen,expo-sqlite,expo-symbols
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua make <project> --only expo-src \
    --real expo-image,expo-document-picker,expo-image-picker,expo-sqlite
```

The first run installs the packages into the revenant store of the checkout (the `REVENANT_CACHE` of the worktree). Each input
folder is emptied before it is written, so a run replaces the previous output of that input only.

## Compare with the spike

```sh
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua compare <reference build> <built build> --only codegen
```

`compare` lists the entries of each input in both folders and reports the entries present on one side only, the entries of
different kinds, the files whose content differs and the links whose targets differ. The built path of a file is replaced by
the reference path before the hash is taken, so a folder made elsewhere is comparable. `--rewrite BUILT=REFERENCE` replaces one
more string on the built side; use it when the two sides read the same package from different folders, as the spike does with
its private cache of the patched `react-native`:

```sh
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua compare paseo-app/build <project>/build --only nitro \
    --rewrite "<revenant store react-native package>=<spike private cache react-native package>"
```

The comparison exits with an error when an input differs, and prints `same (N entries)` for each input that does not.

## Status

| Input | State |
| --- | --- |
| `codegen` | Made. The two files that name the application and `react-native` by a path relative to the output folder differ from the spike only in that relative path, because the output folder sits elsewhere and `react-native` comes from the store. |
| `rn-codegen` | Made. Identical to the spike. |
| `rn-src` | A link to the `react-native` package sources. Same target as the spike once its store path is rewritten. |
| `lib-headers` | Made. Identical to the spike. |
| `expo-jsi` | Made. Identical to the spike. |
| `expo-pods` | Made with the package list above. Identical to the spike. |
| `expo-src` | Made with the package list above. Identical to the spike. |
| `nitro` | Made. Identical to the spike once the `react-native` store path is rewritten. |
| `unistyles` | Made except `swift-header`, which needs the Swift compiler (see below). The response files match the spike once the store path is rewritten. |
| `keyboard` | Made except `react_native_keyboard_controller-Swift.h`, which needs the Swift compiler. `Bridge.h` matches the spike. `flags.rsp` differs in the `react-native` root for yoga (identical trees) and `React` (the application's copy has other files), because the tool reads the revenant package. |
| `screens` | Made. `Bridge.h` matches the spike. `flags.rsp` differs in the same `react-native` root as `keyboard`. |
| `rn-headers` | Not generated yet. The rules of the podspecs that make the flat header set are not written. |
| `expo-core` | Not generated yet. The module maps, `include/ExpoModulesCore` and `swift-header` are missing; `bridging.h`, `ExpoModulesProvider.swift`, `implicit.rsp` and `flags.rsp` are written. |
| `app-assets` | Not generated yet. Its source is not known. |

The headers that Swift generates (`react_native_keyboard_controller-Swift.h`, `unistyles/swift-header`, `expo-core/swift-header`)
are not made by the tool; they need the Swift compiler run over the modules and are not part of this change.
