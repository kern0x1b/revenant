# An application and its overlay

The React Native host builds any Expo application. The application is a read-only checkout; what revenant changes for it
is an overlay folder in `frameworks/ReactNative/examples/<name>/`:

```
host.json     the manifest: bundleId, pods, optionalComponents (the --manifest of inputs.lua)
packaging/    the project's Info.plist, control-rnhost and brand files
overlay/      files that replace the same path in the application's tree
```

`overlay.lua apply` clones the application with APFS clones (`cp -cR`, so no copy of `node_modules` is made) and copies
`overlay/` over the clone. The checkout is never written. A file in `overlay/` that the application does not have stops the
command: the overlay is for another version.

```sh
./xmakew l -P . frameworks/ReactNative/tools/overlay.lua apply <checkout> frameworks/ReactNative/examples/<name> <project>/build/ref/app
./xmakew l -P . frameworks/ReactNative/tools/inputs.lua make <project> --manifest frameworks/ReactNative/examples/<name>/host.json
```

`<project>` holds the project's `xmake.lua`, which includes the host, and a `packaging/` copied from the overlay. Nothing in
revenant names an application; `examples/paseo` is the first one.

## The Paseo example

- Checkout: `$HOME/Git/projects/ios/paseo`, the open-source repository https://github.com/getpaseo/paseo at tag `v0.14.0`
  (commit 8c6de842a3157530c26a7a94c78a3d647fb96ce9), cloned shallow, read only: nothing is committed or pushed there and its
  push url is unset. The tag is the version of the daemon the spike ran against; React Native 0.86.3 and Expo 57 are the same in
  v0.13.2 to v0.16.1. `npm ci` runs in a clone of the checkout, never in the checkout.
- `overlay/node_modules/react-native-unistyles/lib/module/core/useProxifiedUnistyles/listener.native.js` coalesces the theme and
  runtime events of Unistyles per microtask, so a theme change costs one `setState` per subscriber instead of one per event.
- `host.json` carries the bundle id `space.kern0x1b.paseo-ios6.rnhost` and the community pods the application needs.
- The Paseo-specific native modules (`@getpaseo/expo-two-way-audio`, `PaseoHardwareKeyboard`) are not in the host's scope: the
  host has no stub for them, and an application that needs them gets the loud missing-module error.
