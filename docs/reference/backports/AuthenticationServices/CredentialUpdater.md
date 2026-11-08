# ASCredentialUpdater on iOS 6

`ASCredentialUpdater` (iOS 26) is a Swift-only class in the SDK. The backport
(`frameworks/Backports/src/AuthenticationServices/Updater/ASCredentialUpdater.swift`) declares the four reporting methods
with the SDK's labels, each `async throws`, and every one throws code 1004 of
`com.apple.AuthenticationServices.AuthorizationError`, the failed code: iOS 6 has no passkeys and no credential store to
report to, so a caller sees a failure and no report is made.

It is a dylib overlay (`swiftAuthenticationServices`), not a static module. A consumer takes its module and its
`libswiftAuthenticationServices.dylib` from the `revenant@authenticationservices` package, as it takes the other store
dylibs, and needs no `-I` of a built target.

## Checked

`frameworks/Backports/tests/framework_overlay_test.lua` builds the overlay for armv7 iOS 6.0 and typechecks
`frameworks/Backports/tests/AuthenticationServices/updater.swift`, the lines of Telegram's `PasskeysScreen.swift` that make
the updater and report to it, and checks that the same file fails without the overlay.
