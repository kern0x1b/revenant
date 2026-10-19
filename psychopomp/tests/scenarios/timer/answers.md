# Answers

- What it does: a countdown timer for cooking. Pick minutes and seconds, start, pause, resume, reset. When it reaches zero the screen flashes and the phone vibrates if the app is open.
- Screens: one screen. A big remaining-time label, a picker for minutes and seconds, Start/Pause and Reset buttons.
- Data: remember the last duration I used between launches. Nothing else.
- Network: none. No background notifications needed.
- Lowest iOS: 6.0. Releases to check: 6.0.
- Devices: iPhone 4 (iPhone3,1). No real device; emulator only.
- Architectures: whatever the iPhone 4 needs.
- Language: Swift. Interface: UIKit in code, no SwiftUI. Combine: no.
- Frameworks: UIKit, AudioToolbox for the vibration if that is how it is done on 6.0.
- Backports: only if something I asked for is missing on 6.0.
- Look: iOS 6 look.
- Name: "Egg Timer". Bundle identifier: org.example.eggtimer. Version 0.1. Package name same as the bundle identifier. Maintainer: Test User <test@example.org>. Icon: draw a simple one.
- Publishing: the .deb only.
- Confirmed: that is everything, do not ask again.
