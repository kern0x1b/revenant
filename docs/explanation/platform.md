# What revenant is for

An application written for the current iOS SDK runs on an old device. The first targets are the iPhone 4S and the
iPad 2 on iOS 6.1.3; later ones go lower (iOS 5, 4, 3, less memory). Building Telegram from source is one proof
of it, not the goal.

## The backports

Every public API of the iOS SDK, in Objective-C, C and Swift, has a real implementation. The one exception is
hardware the device does not have.

- Nothing is written per iOS version. A configuration names the oldest iOS a build supports; the library holds
  everything newer than that. A new SDK brings only its difference.
- Where the system has its own implementation, the system's wins when the library loads.
- A generator reads the SDK with clang and swift-api-digester and writes the skeleton into the build folder. It is
  never committed. A member nobody implemented fails with its name, for example
  `not implemented: -[NSUUID UUIDString]`.
- Hand-written code lives in `frameworks/Backports/src/<Framework>`. The generator skips what `src` implements.
  One command reports, per framework, how much of it is implemented.
- Clean room: the generator emits facts only (signatures, types, availability, relations). Behaviour is written
  as specs in our own words, from Apple's documentation and measurements, in `docs/reference/backports/`.
  Implementers read the specs, not the SDK. No text of Apple's headers is copied.
- Each framework's tests are `.m` files. One driver, `xmake test`, runs them in parallel against the real macOS
  or Mac Catalyst framework, in ten minutes or less.

## Delivery

One `.deb` for the whole repository, installed once through Cydia. It holds the backports, the frameworks this
repository writes (SwiftUI, Combine, WebKit, and so on) and the Swift runtime. After it is installed, any
application works as on a newer iOS. That includes applications this toolchain did not build.

- A framework iOS 6 does not have is installed at its real path, for example
  `/System/Library/Frameworks/Metal.framework`. An application that imports Metal loads ours, and only that
  application pays for it.
- Members that are missing from a framework iOS 6 already has are found by the loader in the backports
  library. Which mechanism does that is chosen by measurement.
- An application built by today's Xcode is arm64 only, and these devices are 32-bit ARM. Such a binary runs
  there through the recompiler.

## What is worked on

The toolchain and the backports. The emulator, the recompiler, SwiftUI, Combine, WebKit and the agent skills are
frozen: their code stays and builds, and only the shared layout is applied to them.

The order:

1. the generator and the report of what is implemented;
2. the backports move to `frameworks/Backports`, and the registry is deleted;
3. one test driver;
4. implementing what the report shows missing.
