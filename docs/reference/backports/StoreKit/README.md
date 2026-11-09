# StoreKit on iOS 6: manage subscriptions

`AppStore.showManageSubscriptions(in:)` is what Telegram's `AppDelegate.swift:939` calls from "Manage Subscriptions". Apple's
`AppStore` enum is StoreKit 2, which is Swift only and has no Objective-C header, so the SDK declares it in a Swift module
that iOS 6 does not have. The package `revenant@storekit` is the Swift overlay `swiftStoreKit` that carries it.

## What the overlay is

- It is built with `-import-underlying-module`, like the SceneKit, Vision and AuthenticationServices overlays. A Swift module
  named `StoreKit` would otherwise shadow the SDK's clang module of the same name; with the flag it re-exports it, so
  `SKPaymentQueue`, `SKProductsRequest`, `SKMutablePayment` and the rest are still the SDK's, and iOS 6 has all of them.
- A consumer takes `StoreKit.swiftmodule` and `libswiftStoreKit.dylib` from the package, puts the module folder on `-I` and links
  the dylib. Telegram's compile before this change had no `-I` for StoreKit, and failed with `cannot find 'AppStore' in scope`.
- `showManageSubscriptions(in:)` is `@MainActor`, `async` and `throws`, like the system one. It calls
  `-[UIApplication openURL:]` for `prefs:root=STORE` and throws `URLError(.unsupportedURL)` when the system refuses the URL.
  It does not use the scene, because iOS 6 has no scenes.

## Why the Settings pane

iOS 6.1.3 has no page for subscriptions that an app can open:

- The App Store app registers the schemes `itms-apps`, `itms-appss` and `itms-services`. The strings the iOS 6.1.3 shared cache
  holds for `itms-apps:` are the actions `?action=software`, `?action=updates`, `?action=newsstand` and `?action=passbook`, and
  the AirPort Utility links. The cache has no `manageSubscriptions`, `wa/manage` or `wa/subscriptions` string.
- The page `https://apps.apple.com/account/subscriptions`, which the first version of this overlay opened, is a web page for a
  browser that hands over to the App Store of a newer system. MobileSafari opens it; nothing on it manages a subscription.
- Settings registers the scheme `prefs`. On an iPhone 4S with iOS 6.1.3, `uiopen "prefs:root=STORE"` made Settings show its
  "iTunes & App Stores" pane with the signed-in Apple ID at the top. That is where iOS 6 keeps the account, and the Apple ID
  leads to the account page where subscriptions are managed.

Not measured: the page behind the Apple ID, and the same call from an app that has a window scene, because the phone was in
airplane mode and the account page loads from the network. The pane itself opens without the network.

## Tests

- `tests/storekit_test.lua`: the URL the overlay opens, and that the compiled `SKPayment+ApplicationUsername.o` implements the
  two members it adds.
- `tests/framework_overlay_test.lua`: the overlay builds for armv7 iOS 6.0 against the lowered SDK, Telegram's lines
  (`AppStore.showManageSubscriptions(in:)` and the `SKPaymentQueue` observer in `InAppPurchaseManager`) typecheck with it,
  and the same fixture fails with `cannot find 'AppStore' in scope` without it.
