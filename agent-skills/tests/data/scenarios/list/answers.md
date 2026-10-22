# Answers

- What it does: a shopping list. I add items, tick them off when bought, and delete them.
- Screens: one screen, the list. A text field and an Add button at the top, the items below. Tapping an item ticks or unticks it. Swipe to delete. An "Clear bought" button in the navigation bar removes ticked items.
- Data: the list must survive quitting the app and rebooting the phone. No accounts, no sync.
- Network: none. Notifications: none.
- Lowest iOS: 5.1.1. Releases to check: 5.1.1 only.
- Devices: iPhone 3GS (iPhone2,1). I have no real jailbroken device at hand; the emulator is enough.
- Architectures: whatever the 3GS needs.
- Language: Objective-C. Interface: UIKit built in code. No SwiftUI, no Combine.
- Frameworks: only what the system on 5.1.1 has. No backports unless you find one is required.
- Storage: your recommendation.
- Look: the normal iOS 5 look.
- Name: "Groceries". Bundle identifier: org.example.groceries. Version 1.0. Package name same as the bundle identifier. Maintainer: Test User <test@example.org>. Icon: draw a simple one.
- Publishing: just the .deb file.
- Confirmed: these are all my decisions; go ahead without asking again.
