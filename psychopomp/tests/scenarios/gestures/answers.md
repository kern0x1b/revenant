# Answers

- What it does: a sticker board. Coloured rounded squares on a canvas that I can drag with one finger, pinch to resize, rotate with two fingers, double-tap to change colour, and long-press to delete. A "+" button adds a new square in the middle.
- Screens: one full-screen canvas with a toolbar at the bottom holding "+" and "Clear".
- Data: keep the board (positions, sizes, rotations, colours) between launches.
- Network: none.
- Lowest iOS: 6.1.3. Releases to check: 6.1.3.
- Devices: iPhone 4S (iPhone4,1). No real device; emulator only.
- Architectures: whatever the 4S needs.
- Language: Swift. Interface: UIKit in code. No SwiftUI. Combine: no.
- Frameworks: UIKit, QuartzCore if needed. Backports only if something is missing.
- Look: iOS 6 look for the toolbar.
- Name: "Stickers". Bundle identifier: org.example.stickers. Version 1.0. Package name same as the bundle identifier. Maintainer: Test User <test@example.org>. Icon: draw a simple one.
- Publishing: the .deb only.
- Confirmed: final, go ahead.
