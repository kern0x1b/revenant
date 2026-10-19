# DCAppAttestService, iOS 14.0

`DCAppAttestService` is App Attest: an application asks it for a key pair made in the device's Secure
Enclave, has Apple certify that key against the application, and afterwards has the enclave sign an
assertion for each request so its own server can check that the instance talking to it is the one
Apple attested. It is the second half of what `DCDevice` starts, and `facts/DeviceCheck/DCDevice.md`
named it as not carried when it carried the first half; this is the second half.

## What the devices this port runs on are

The key App Attest mints lives in the Secure Enclave, a hardware component that came with the A7 of
the iPhone 5s. An iPhone 4S (A5) and an iPad 2 (A5) have none, and the release runs no App Attest
daemon in any case, so there is no key to make, nothing to certify and nothing to sign with. This is
a wall of the kind COORDINATION §2 allows: hardware the device does not have.

## What the port answers

Each line says whether it was measured or is reasoning.

- `+sharedService` is one `DCAppAttestService`, made once inside a `dispatch_once` and the same object
  every time it is asked. Measured on the host: asked twice, the same object.
- `-isSupported` is **NO**. Measured on the host, whose `-isSupported` answers NO — a Mac is a platform
  that does not provide the service, and the header documents NO for a device type that does not
  provide it. This is also the answer the hardware above gives.
- `-generateKeyWithCompletionHandler:` calls the handler with a **nil key id** and an `NSError` in
  `DCErrorDomain` with code **`DCErrorFeatureUnsupported`** (1), which the header defines as
  "DeviceCheck is unavailable on this device". Measured on the host: nil key id,
  `com.apple.devicecheck.error`, code 1. The call is not made before the method returns, and the
  handler is not called on the main thread — both measured, and both the way this package's own
  `-generateTokenWithCompletionHandler:` on `DCDevice` answers on a release with no daemon.
- `-attestKey:clientDataHash:completionHandler:` and `-generateAssertion:clientDataHash:completionHandler:`
  call the handler with a **nil object** and an error with code **`DCErrorInvalidInput`** (2), also
  off the main thread and after the call. Measured on the host, which answers code 2 for *any* key a
  caller can name: both a nil key id and a well-formed one (`ABCD0123-…`) with a 32 byte hash come
  back with code 2. That is the point — a key of a device that never made one is not a key that can
  be attested or signed with, whatever the caller passes, so there is nothing to distinguish and the
  port invents no other answer.
- A **nil handler is ignored**. The release, given none, would call it when the service replied, and
  no service ever replies here; `Foundation/DCDevice.m` already takes this decision for the token
  path of the same framework, and this follows it rather than inventing a second one.

## What was measured, and what was not

Measured: everything above marked measured, on the host's own DeviceCheck through MacOSX.sdk, which
is a platform that does not run the service. The error domain `com.apple.devicecheck.error` and the
codes come from the same place and are already in the registry for `DCDevice`.

Not measured: Apple's own App Attest on a device that *has* a Secure Enclave. None of the devices this
port runs on has one and the host has none, so what a real attestation answers is not known here and
is not claimed: this file says what a device without the service answers, which is what the port is.

The two rows of the corpus for `DCDevice.currentDevice` and `DCDevice.supported` are detection
artifacts, not work: the accessors are `+[DCDevice currentDevice]` and `-[DCDevice isSupported]`, a
class method and an instance method, and the corpus's property reader looks for the two instance
spellings of each name. Both accessors are carried and in `Foundation/DCDevice.m`, and the host
answers `-[DCDevice isSupported]` with YES, which is what the port answers.
