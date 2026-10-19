---
name: swiftui
description: SwiftUI for an old iOS app with Charon at the 0.8.10 pin — why Apple's SwiftUI cannot serve (iOS 13, arm64 only in the SDK), that Eidolon, a separate reimplementation of the SwiftUI API on the UIKit of iOS 6, has no Charon package at 0.8.10 (no charon@eidolon), how to check a later pin for one, what to tell the user and recommend instead (UIKit in Swift, with Combine if the data flow wants it), and what not to do in its place. Use during the interview when the user asks for SwiftUI, at the code step when PROJECT.md says SwiftUI, when import SwiftUI finds no module, or when someone asks whether a SwiftUI app can run on iOS 6.
---

# SwiftUI on old iOS

Apple's SwiftUI is iOS 13 and later, and the SDK's module cannot serve an old release: in the
`charon@iphoneos-sdk` 16.4 package, `SwiftUI.framework/Modules/SwiftUI.swiftmodule` holds only
`arm64` and `arm64e` interfaces, built for `-target arm64-apple-ios16.4`, and no old release has the
framework. Eidolon (<https://github.com/kern0x1b/eidolon>) is a separate project that
re-implements the SwiftUI *API* on the UIKit of iOS 6, as a Swift module named `SwiftUI`, with Styx
as its `Combine` (Eidolon's `README.md` at commit `10f87e0`).

This skill says whether an app can have it, and what to do when it cannot. Read `PROJECT.md` first:
the interface is recorded under `## Code` (skill `init`).

## 1. Is there a package?

**At the pin, no.** Charon's package repository at `charon-repo-0.8.10` has 18 packages and no
`charon@eidolon`: `packages/e/` holds only `emulator-guest`. Nothing in the addon at `v0.8.10`
names Eidolon or SwiftUI. An app built with this plugin at 0.8.10 has no SwiftUI. The line
`import SwiftUI` itself compiles for armv7: the SDK's `SwiftUI.framework` has a Swift interface
only for arm64 and arm64e, and beside it a Clang `module.modulemap` over `SwiftUI.h`; what the
import finds for armv7 declares no view. Measured at the pin: the bare import builds, and
`struct Probe: View { var body: some View { Text("x") } }` stops with
`error: cannot find type 'View' in scope` and `error: cannot find 'Text' in scope`.

When the project pins a later Charon, check that tag before you answer the user:

```
curl -s -o /dev/null -w "%{http_code}\n" https://raw.githubusercontent.com/kern0x1b/charon/charon-repo-<X>/packages/e/eidolon/xmake.lua
```

`404`: no package at that tag, and §2 applies. `200`: the tag has one, and this skill predates it.
Read that recipe's `set_description` and its configs, tell the user that this skill does not cover
it, and check every step against the recipe and Charon's README at that tag before you describe
anything to the user.

## 2. What to tell the user when there is none

- **A SwiftUI app cannot be built with this stack at this pin.** Eidolon's own repository builds
  with its own scripts: `eidolon/build.sh` calls the compiler and clang by hand for
  `armv7-apple-ios`, iOS 6.0, against packages installed in a private xmake global directory
  (`xmake-global/`, its README's "Requirements"), and its tests need an emulator lab it points to
  with `EMULATOR_LAB`. That is not a path for an app: a private xmake store is what this plugin
  never uses, and those scripts are not an interface anyone supports.
- Do not copy Eidolon's sources into the project, compile them as a target of your own, or write a
  small imitation of SwiftUI views over UIKit. Each is a second, unsupported SwiftUI the user would
  have to maintain, and none of it is what they asked for.
- At the interview's interface question, say this and recommend **UIKit in Swift** (skill `swift`),
  built in code from the release's own controls, with Combine (skill `combine`) if the app's data
  flow wants publishers and `ObservableObject`/`@Published` state. An interface written in UIKit
  now is not a SwiftUI interface later: say that too. If the user would rather wait for a package,
  record that in `PROJECT.md` and stop.
- Record the answer in `PROJECT.md` under `## Code` (interface: UIKit, and why; or waiting for a
  package), so a later session does not reopen it.

## 3. What Eidolon says of itself

For the user who asks what waiting would bring, and only as Eidolon's own account at `10f87e0`
(its `README.md`); none of it is reachable from a project at the pin, and none of it was checked
by this plugin:

- It targets iOS 6 on armv7, with Charon's Swift runtime carried in the app.
- Its ledger of what is implemented, ignored or simplified is `eidolon/README.md` in that
  repository (in Russian).
- By its own count against Apple's SwiftUI interface for iOS 16.4: of 4740 public declarations,
  3233 (68%) are callable as Apple writes them, 314 (7%) exist with a different signature, 927
  (20%) are absent, and 266 (6%) belong to types an iOS 6 phone cannot have.

Tell the user it is a project in progress, with that measure, and that the plugin will describe it
once Charon packages it.

## Traps

- "SwiftUI works on iOS 6" said without §1 → say which is true at the project's pin. Reason: it
  builds in Eidolon's repository, not through a package an app can require.
- `import SwiftUI` expecting the SDK's module → there is none for an old release, even though the
  import compiles (§1). Reason: the SDK's SwiftUI is arm64 and iOS 13 and later, and for armv7 the
  first `View` fails with `cannot find type 'View' in scope`; only a packaged Eidolon could serve
  an iOS 6 app.
- Eidolon's `build.sh`, its `xmake-global/` or a private `XMAKE_GLOBALDIR` to "just get it working"
  → no. Reason: a private store rebuilds the toolchain on its own, and it is not the project's
  pinned Charon.
- A hand-made SwiftUI look-alike on UIKit, to meet the request → UIKit in Swift, said as such.
  Reason: the user gets neither SwiftUI nor an honest UIKit app.
- `-Xfrontend -disable-availability-checking` to get past an API the release lacks → the release's
  API. Reason: it makes every `#available` true — measured on an emulated iPhone 4S, iOS 6.1.3:
  `#available(iOS 7.0, *)` answers false without it and true with it — so the guarded call runs on
  a release that lacks it; the skill `self-review` refuses the flag.
