# Exporting the JavaScript bundle for the JavaScriptCore host

The React Native host of revenant runs the application's JavaScript on JavaScriptCore, not Hermes. An Expo export made for Hermes
does not run correctly there, and `frameworks/ReactNative/tools/export_bundle.lua` makes the one that does.

```
./xmakew l -P . frameworks/ReactNative/tools/export_bundle.lua [--output DIR] APP_DIR
```

APP_DIR is the application's folder with its `babel.config.js`. The result is `DIR/bundle.js`, by default
`APP_DIR/dist-jsc/bundle.js`.

## What differs from the Hermes export

| Hermes export | This export | Why |
| --- | --- | --- |
| babel profile `hermes-stable` | profile `default` | With the Hermes profile async functions stay native and return the engine's own promises. React Native replaces `global.Promise` with its polyfill unless `HermesInternal` says the engine owns it, so `result instanceof Promise` is false for every async result. The `default` profile compiles async functions to generators over `global.Promise`, as for any JavaScriptCore target. |
| bytecode | none | JavaScriptCore reads source. |
| `inlineRequires: false` | `inlineRequires: true` | With it off every module of the 24 MB bundle runs at start. With it on a module runs at its first use. On an iPhone 4S the time from launch to `Running "main"` went from 16.9 to 7.8 seconds, and the resident memory after start from about 200 MB to about 100 MB. |
| nothing in front | `src/jsc-prelude.js` | Hermes has `atob` and `btoa`; JavaScriptCore does not, and the application's relay handshake calls them. |

No `HermesInternal` object is faked: the engine is what it is, and the bundle is made for it.

## How it works

The tool copies `babel.config.js` to `babel.config.hermes.js` and `metro.config.cjs` to `metro.config.original.cjs`, writes a babel config that loads the copy and sets
`unstable_transformProfile` to `default` on `babel-preset-expo`, runs `npx expo export --platform ios --no-bytecode`, and puts
the original back whether the export worked or not. It refuses to start if `babel.config.hermes.js` is already there, because
that means an earlier run was cut off and the two files need a look.
