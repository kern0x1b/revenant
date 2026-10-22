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
- Each framework's tests are `.m` files (the Swift frameworks' are `.swift`). One driver, `./xmakew test -P .`, runs them in parallel against the real macOS framework, in ten minutes or less.

## Delivery

The delivery is a Debian package per control file, installed through Cydia. The backports are one of them:
`org.revenant.backports`, written by `./xmakew deb -P .` from every Backports library of the build, which a target that
links one of them requires. The Swift runtime and libc++ are packages of their own, which it depends on. What exists
today is the WebKit port (`space.kern0x1b.rev`), the SwiftUI showcase (`space.kern0x1b.swiftui`), the CallKit tweak
and the test packages. The aim is that after the backports package is installed, any application works as on a newer
iOS, including applications this toolchain did not build. That is not yet measured on a device, and the package has
not yet been run end to end on a real build.

- An application built by today's Xcode is arm64 only, and these devices are 32-bit ARM. Such a binary runs
  there through the recompiler, which binds its imports to the backports libraries when it translates it.
  An application this toolchain builds links them directly.
- The libraries live in `/usr/lib/revenant/org.revenant.backports/`, never over a system file, so the same package stays correct on a
  later iOS that has the real framework. Only an application that links a library loads it.
- Where the system has its own implementation it wins at run time: Objective-C through the class alias, which is built. The
  forwarder for C and Swift is not built yet. How, and what is still to measure: `backports-loading.md`.

## What is worked on

The toolchain and the backports. The emulator, the recompiler, SwiftUI, Combine, WebKit and the agent skills are
frozen: their code stays and builds, and only the shared layout is applied to them.

The order:

1. the generator and the report of what is implemented;
2. the backports move to `frameworks/Backports`, and the registry is deleted;
3. one test driver;
4. implementing what the report shows missing.
