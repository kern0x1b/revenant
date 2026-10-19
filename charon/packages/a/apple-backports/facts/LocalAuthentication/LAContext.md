# LAContext, iOS 8

Introduced in iOS 8: the way an application asks whether the owner of the device can be authenticated by a fingerprint
(iOS 8) or by the passcode (iOS 9), and asks for it. Later releases added Face ID and the biometry type, the cancel
title, the reuse duration, credentials and the invalidation of a context.

Source: the host's own LocalAuthentication under Mac Catalyst, held against the port by the `localauth` group of
`tests/backports/host/uikit2/run.sh`, and the shared cache of iOS 8.0 for the text of the error a device without a
fingerprint sensor answers ("Biometry is not available on this device."). The host has a biometric sensor, so what it
answers to a question about biometry is not the answer of the devices this port runs on; the port answers as a device
with none.

## What the devices this port runs on are

An iPhone 4S and an iPad 2 have no fingerprint sensor and no Face ID, and iOS 6 gives an application no way to ask for
the passcode: the passcode is checked by the lock screen and the application cannot put it up. So:

- `canEvaluatePolicy:error:` answers `NO` for `LAPolicyDeviceOwnerAuthenticationWithBiometrics`, with
  `LAErrorBiometryNotAvailable` (-6, the same value as `LAErrorTouchIDNotAvailable`) in `LAErrorDomain`, described as
  "Biometry is not available on this device." An application that asks first, as it is told to, offers its own
  passcode or none.
- The same question for `LAPolicyDeviceOwnerAuthentication` answers `NO` with `LAErrorNotInteractive` (-1004): the
  authentication would need an interface the application cannot display. It is not `LAErrorPasscodeNotSet`, since the
  port cannot tell whether a passcode is set and says nothing false about it.
- `evaluatePolicy:localizedReason:reply:` and `evaluateAccessControl:operation:localizedReason:reply:` call the
  reply with `NO` and the same error, after the call returns and off the main thread, as the system does. Nothing
  ever succeeds.
- `evaluatedPolicyDomainState` is `nil` and `biometryType` is `LABiometryTypeNone`.

## What the port answers as the system does

A new context has no titles, no failures and no reuse duration; the titles, `maxBiometryFailures`,
`touchIDAuthenticationAllowableReuseDuration` (kept as given, with no clamp), `localizedReason` and
`interactionNotAllowed` are kept. After `invalidate` every question and every evaluation fails with
`LAErrorInvalidContext` (-10), described "Authentication failure." with the debug description "Invalid context.". A
policy the release does not know, and a reason that is `nil` or empty, raise `NSInvalidArgumentException` with the
system's reason; a `nil` reply is allowed. A credential of the application-password type or of the smart card PIN type
is kept, `isCredentialSet:` says so and a `nil` credential removes it; type -1 answers `NO`; any other type raises.
`LAErrorDomain` is `com.apple.LocalAuthentication` and the longest reuse duration is 300 seconds.

## What it does not do

There is no authentication: nothing ever answers `YES`, and the codes that say the user cancelled, failed or chose the
fallback are never reported. A watch policy is not carried. `interactionNotAllowed` is kept and changes nothing, since
every evaluation already fails without an interface; the host does not keep it, so this is not held to a record.
