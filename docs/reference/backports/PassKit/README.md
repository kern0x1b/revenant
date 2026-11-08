# PassKit on iOS 6: the Swift module

`PKMerchantCapability` is an option set whose Objective-C constants are `PKMerchantCapability3DS`, `Credit`, `Debit` and `EMV`.
The SDK's apinotes import them as `threeDSecure`, `credit`, `debit` and `emv`, and the SDK's Swift overlay adds
`capability3DS`, `capabilityCredit`, `capabilityDebit` and `capabilityEMV` as aliases (`PassKit.swiftinterface`). The overlay is
shipped for arm64e only, so an armv7 build has the apinotes names and not the aliases, and Telegram's
`BotCheckoutControllerNode.swift` (`.capability3DS`) fails. The cause is the missing overlay, not the lowering: the lowering keeps the
`threeDSecure` name and has no Swift name of its own to lose.

`src/PassKit/PassKit.swift` is the backport's overlay: the four aliases as static members of `PKMerchantCapability`, each
deprecated for iOS 17 and renamed to the apinotes name as the SDK declares it, and without the SDK's `introduced: 8` and `9`: the
lowering takes `PKMerchantCapability3DS`, `Credit` and `Debit` as implemented, so the constants they alias exist on iOS 6. It is built with `-import-underlying-module`; a consumer builds the `PassKit` target of the `Swift`
component, passes its module folder with `-I` and links `libPassKit.a`.

## Checked

Measured: `frameworks/Backports/tests/framework_overlay_test.lua` builds the module for armv7 iOS 6.0 against the lowered SDK,
typechecks `frameworks/Backports/tests/PassKit/overlay.swift`, which uses all eight spellings in a `PKPaymentRequest`, and checks
that the same file fails without the module (`has no case 'capability3DS'`).
