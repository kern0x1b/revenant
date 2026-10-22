# Answers

- What it does: shows the current public holidays for a country I choose, fetched from https://date.nager.at/api/v3/PublicHolidays/<year>/<country code> (JSON, no key).
- Screens: a split layout on the iPad: a country list on the left (a fixed list of ten countries is fine), the holidays of the current year on the right with date and local name. A pull-to-refresh or a Reload button, and a clear message when the request fails.
- Data: cache the last successful response per country so the app shows something offline.
- Network: HTTPS GET to the address above. If the server cannot be reached from iOS 6.1.3 because of TLS, tell me and show the error in the app rather than faking data.
- Lowest iOS: 6.1.3. Releases to check: 6.1.3.
- Devices: iPad 2 (iPad2,1). No real device; emulator only.
- Architectures: whatever the iPad 2 needs.
- Language: Objective-C. Interface: UIKit in code. No SwiftUI, no Combine.
- Frameworks and backports: your recommendation; prefer what 6.1.3 already has.
- Look: iOS 6 look.
- Name: "Holidays". Bundle identifier: org.example.holidays. Version 1.0. Package name same as the bundle identifier. Maintainer: Test User <test@example.org>. Icon: draw a simple one.
- Publishing: a .deb, and prepare a Cydia repository directory for it that I will host myself later on a static web host.
- Confirmed: these are my final answers.
