# On a phone

The screens of the demo app, drawn by the engine on an iPhone 4S running iOS 6.1.3 (armv7) — nothing here is an emulator.
[`device/`](device/) holds them: the symbol set, a social feed, settings, a dashboard, a store, contacts, token
search and an onboarding pager. `frameworks/SwiftUI/tools/device.lua shots` installs the demo, has the app render a
scenario in its own process and fetches the picture; `frameworks/SwiftUI/tools/device.lua shots --live` takes a picture
of the real screen.
