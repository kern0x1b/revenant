# The icon and launch image of a React Native application

The host application carries nothing of its own: the name, the icon and the launch image come from the Expo configuration of the
application being built.

```
./xmakew l -P . frameworks/ReactNative/tools/app_assets.lua [--output DIR] APP_DIR
```

APP_DIR is the application's folder with `app.config.js` or `app.json`. The tool reads the configuration with `npx expo config` and
writes, by default into `APP_DIR/dist-assets`:

| File | From |
| --- | --- |
| `Icon.png`, `Icon@2x.png` (57 and 114 pixels) | `icon` |
| `Default.png`, `Default@2x.png` (320 by 480 and 640 by 960) | `image`, `imageWidth` and `backgroundColor` of the `expo-splash-screen` plugin; a plain background when the plugin is absent |
| `Info.fragment.plist` | `name` as `CFBundleDisplayName`, and `CFBundleIconFiles` for the two icons |

iOS 6 knows no asset catalogue and no dark appearance, so the pictures are plain files and the light background is used. The files go
into the bundle as `app.resources` and the fragment's keys into its Info.plist.
