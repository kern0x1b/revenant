# Which platform the process is on, and the low power mode, iOS 9.0 to 26.1

Four properties: `iOSAppOnMac`, `macCatalystApp`, `iOSAppOnVision` and `lowPowerModeEnabled`.

Source: the SDK 26.2 headers. Every one of them answers NO on the port's own release, and that is the
whole answer rather than a stub.

- An iPhone 4S and an iPad 2 are not a Mac, so `iOSAppOnMac` and `macCatalystApp` are NO. A Mac
  Catalyst application is one built against the Mac SDK for iOS; the port's target is an iOS device,
  and the flag says which kind of build this is.
- `iOSAppOnVision` says the process runs on a Vision Pro. The device this port runs on is not one, and
  the answer a device without the hardware gives is the answer here.
- `lowPowerModeEnabled` is the mode that arrived with iOS 9 and needs the hardware that arrived with
  iPhone 6. iOS 6.1.3 has no such mode to be in, so the answer is NO -- the same one iOS 9 gives on a
  device that cannot enter it.

These four are the "a device without it answers as the platform documents" case, and each is written
down rather than left to be discovered.
