# rn-probe: one host for the coverage rows the Paseo host cannot measure

The Paseo host carries only the modules Paseo uses. These rows are native but absent there: expo-battery, expo-blur,
expo-calendar, expo-cellular, expo-location, expo-media-library, expo-sensors, expo-speech, expo-splash-screen,
expo-task-manager, expo-video, expo-video-thumbnails, expo-symbols, and the libraries in `host.json` `pods`
(slider, datetimepicker, picker, segmented-control, netinfo, viewpager, bootsplash, view-shot). expo-lottie is left out:
it has no Swift part and no lottie-ios pod yet.

Expo modules are chosen by the environment, not by host.json (`RN_APP_MODULES` is for third-party modules):

    RN_EXPO_REAL=expo-battery,expo-blur,expo-calendar,expo-cellular,expo-location,expo-media-library,expo-sensors,expo-speech,expo-splash-screen,expo-task-manager,expo-video,expo-video-thumbnails,expo-symbols

`RN_EXPO_REAL` must be set explicitly: the coverage-driven choice drops rows whose status is `missing` (expo-blur).
Each package must be in `RN_PKG_DIRS` (its recipe under packages/e) or in the reference application's node_modules.
Backports: the host's required set plus Accelerate, CoreMedia, AVFoundation, Photos and MediaPlayer (see xmake.lua).

Rows that need personal data (location, media-library, calendar) are "registered only": the probe checks that the module
answers, never reads data. The probe bundle is built from `src/probe/modules.js` itself (no copy here); the UI cells are added there.

`xmake.lua` holds the project name and the Backports list as literals and includes `examples/host.lua`, which the Paseo example shares; `tests/example_projects_test.lua` keeps the literals equal to `project` and `backports` of `host.json`.

Status: step 0 only, nothing built. The `pods` entries are bare package names; the codegen module name after the colon
(as in the Paseo host, `pkg:module`) is taken from each package's codegenConfig when its recipe is installed (step 2)
and added then. Pager-view's npm name is `@react-native-community/viewpager` (recipe react-native-community-viewpager).
