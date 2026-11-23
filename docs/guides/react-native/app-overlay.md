# An application and its overlay

The React Native host builds any Expo application. The application is a read-only checkout; what revenant changes for it
is an overlay folder in `frameworks/ReactNative/examples/<name>/`:

```
xmake.lua     the project's root: it includes the host from the revenant checkout (`REVENANT_PATH`)
host.json     the manifest: bundleId, pods, modules, optionalComponents (the --manifest of inputs.lua)
packaging/    the project's Info.plist, control-rnhost and brand files
overlay/      files that replace the same path in the application's tree
```

`overlay.lua update` brings the checkout to the newest upstream (the operator runs it before a build; no build step does), and `overlay.lua apply` clones the application with APFS clones (`cp -cR`, so no copy of `node_modules` is made) and copies
`overlay/` over the clone. The checkout is never written. A file in `overlay/` that the application does not have stops the
command: the overlay is for another version.

After the overlay, `apply` runs the application's own `scripts/postinstall-patches.mjs` in the clone, with the clone's `node_modules/.bin` first on PATH, as npm does after an install. The application is installed with `npm ci --ignore-scripts`, which skips it, and without its patches the bundle is not the application: on 2026-11-22 the bundle of the unpatched Paseo 0.16.2 had no `BottomSheetModalInternalProvider` export (all 11 patches were unapplied) and its root screen stopped at "Element type is invalid" on the iPad 2. The script leaves a patch that is already applied alone, and a patch that does not apply stops `apply`. `tests/overlay_test.lua` checks the place, the PATH, that the application folder is not written, and the failure.

```sh
./xmakew l -P . frameworks/ReactNative/tools/overlay.lua apply <checkout> frameworks/ReactNative/examples/<name> <project>/build/ref/app
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua make <project> --manifest frameworks/ReactNative/examples/<name>/host.json
```

`<project>` is a folder with `xmake.lua` and `packaging/` copied from the overlay folder and the `build/ref/app` link above. Nothing in
revenant names an application; `examples/paseo` is the first one.

## The Paseo example: always the latest upstream

- Checkout: `<checkout>`, a folder outside revenant that holds the open-source repository https://github.com/getpaseo/paseo, shallow, read only:
  nothing is committed or pushed there and its push url is unset. Before each build of Paseo the operator runs

  ```sh
  ./xmakew l -P . frameworks/ReactNative/tools/overlay.lua update <checkout> https://github.com/getpaseo/paseo [--main]
  ```

  which fetches, checks out the newest release tag detached (`--main`: the head of the default branch) and prints the tag and
  commit, which the build's report records. No build step calls it and no daemon or schedule keeps the checkout fresh: it is the operator's first command of a build. First run: v0.16.1,
  commit c09a3d81e772a747dd11bca43d860f3518f07c2d; latest built: v0.16.2, commit 2ee30f4164af42ba209236ab3a31bf9532592fc3 (the overlay
  applies unchanged, the isolated host builds, every pod of the manifest matches its recipe version).
- A newer upstream that breaks the overlay (a patched file is gone, React Native or Expo changed) is a finding: the overlay in
  `examples/paseo/` is corrected, never the checkout. `apply` stops when an overlay file has no counterpart.
- `npm ci` runs in a clone of the checkout, never in the checkout.
- `overlay/node_modules/react-native-unistyles/lib/module/core/useProxifiedUnistyles/listener.native.js` coalesces the theme and
  runtime events of Unistyles per microtask, so a theme change costs one `setState` per subscriber instead of one per event.
- `host.json` carries the bundle id `space.kern0x1b.paseo-ios6.rnhost`, the community pods the application needs and its own
  Expo modules (`modules`: packages of its workspace or `node_modules`, or folders of its own `packages/app/modules`, that are not part of the Expo SDK
  and carry an `expo-module.config.json`). Those are built from the application's sources, with no recipe and no change to them: `inputs.lua`
  adds them to the Expo inputs and `isolate.lua` passes them to the build as `RN_APP_MODULES`. `@getpaseo/expo-two-way-audio` is
  the one the Paseo example names; its iOS 13 voice-processing audio engine is the Backports' (`AVAudioEngine` on a
  VoiceProcessingIO unit, crutch C12), not a change to the module.
- The Paseo example names two of the application's local iOS modules, `paseo-hardware-keyboard` and `paseo-window-layout`, and the pod
  `paseo-scroll`: they live in `packages/app/modules` and are built from their sources by the host. Without the first two the application
  stops at start (`Cannot find native module 'PaseoHardwareKeyboard'`, measured on the iPad 2 on 2026-11-22). `paseo-terminal` is not built.

## The application names its Backports libraries

The libraries of the `revenant@backports` requirement are the application's: the `backports` array of its `host.json` lists them, and the host takes that list as it stands, with none of its own and no override. Each example has its own `xmake.lua` with the project name and the list as literals (xmake reads the file without `import()` or `io`, so it cannot read `host.json`); `tests/example_projects_test.lua` keeps them equal to `project` and `backports` of `host.json`, so a library is added to both. An application whose own `xmake.lua` has a literal list (`configs = {libraries = "..."}`) is read from there first. A module that needs another framework on the phone (for example the audio engine of `@getpaseo/expo-two-way-audio`) adds that library to the application's list only. The host's `on_load` checks the list against the libraries the host itself links (`tools/backports_libraries.lua`, `HOST_REQUIRED`) and refuses a build whose list lacks one, naming it; a project that gives no list, in `xmake.lua` or in `host.json`, is refused too.

The Expo provider reads the `apple` block of a package's `expo-module.config.json` and, when there is none, the `ios` block, as Expo's own `getAppleConfig` does (`apple` wins when both are present). It does not read the `platforms` array: a package the application lists is one the application means to build for iOS, and a module whose `platforms` omit iOS has no Apple block to read.
