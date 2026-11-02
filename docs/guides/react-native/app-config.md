# Giving the host the application's Expo manifest

`expo-constants` reads the manifest of an application from `EXConstants.bundle/app.config` inside the application bundle. An Xcode
project gets that file from a build phase. The iOS 6 host is not built by Xcode, so
`frameworks/ReactNative/tools/app_config.lua` makes it:

```
./xmakew l -P . frameworks/ReactNative/tools/app_config.lua --output DIR APP_DIR
```

APP_DIR is the folder with the application's `app.json` or `app.config.js`. The tool runs `npx expo config --type public --json`
there and writes `DIR/EXConstants.bundle/app.config`. Copy the `EXConstants.bundle` folder into the host's `.app` before it is
signed and packed.

## Why it is needed

Without the file `Constants.expoConfig` is `null`. `expo-linking` reads the `scheme` from it, and `getInitialURL` raises
"expo-linking needs access to the expo-constants manifest", so the first screen of an Expo Router application is the error
boundary. A hand-written file with a few fields hides that and hides every other field the application reads from the config
(`version`, `slug`, `extra`, `ios.bundleIdentifier`), so the host takes the real one.
