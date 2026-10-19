# DCDevice, iOS 11.0

Introduced in iOS 11.0: the device a token for the DeviceCheck service is made
for. An application that carries no `@available` guard around it, or that was
recompiled for a release without the framework, still links the class and asks
it whether it is supported. This package carries the class so that the question
has an answer.

Source: DeviceCheck of the arm64 shared cache of iOS 12.0, read with the
symbols of the image: `-[DCDevice isSupported]` at `0x19e6794f8`,
`+[DCDevice currentDevice]` at `0x19e679170`,
`-[DCDevice generateTokenWithCompletionHandler:]` at `0x19e6791f0` and the
blocks it hands to the daemon. The names, the domain and the codes of the error
are from the SDK 16.4 header `DCError.h` and from the host's DeviceCheck through
Mac Catalyst, which agrees with the release on every line below except the one
about the token. iOS 11.0 is not
in the cache this package holds for that release, and the arm64e caches of 16.0
and 18.0 come without the symbol file the reader needs, so neither was read.

## What the release answers

Each line says whether it was measured or is the header's own word.

- `+currentDevice` answers one shared object: asked twice, it is the same
  object. The release makes it in a block that runs once; measured on the host.
- `-isSupported` answers **YES** and does nothing else: the function is a
  constant, so it does not ask the hardware or the daemon. Read from the code of
  the release; the host answers YES too. The header's own advice is to test for
  availability with it and then to generate a token, and the answer that decides
  is the one `-generateTokenWithCompletionHandler:` gives.
- `DCErrorDomain` is `com.apple.devicecheck.error`. Read from the release and
  measured on the host.
- The codes are `DCErrorUnknownSystemFailure` 0, `DCErrorFeatureUnsupported` 1,
  `DCErrorInvalidInput` 2, `DCErrorInvalidKey` 3 and `DCErrorServerUnavailable`
  4, and the header says of the second that DeviceCheck is unavailable on this
  device. Documented contract.
- `-generateTokenWithCompletionHandler:` makes a connection to the mach service
  `com.apple.devicecheckd`, asks it for an opaque blob, and hands the data or
  the error the daemon answers to the completion handler. When the connection
  cannot be made, the handler it installs for that failure builds an error of
  code 0, `DCErrorUnknownSystemFailure`, with no user info, and passes that.
  Read from the code of the function and of its two blocks. The reply arrives
  over the connection, so the handler is not called before the method returns.
  On the host, asked here, a token of 2207 bytes came back with no error, from a
  thread that was not the main one.

## What the port answers

`+currentDevice` and `-isSupported` are as above: one shared object, and YES.
The port is faithful there, and it is not turned to NO, since no release ever
answered NO to it.

`-generateTokenWithCompletionHandler:` has no daemon to reach on iOS 6, so it
does what the release's own failure path does with one difference of code: the
handler is called from a background queue, after the method has returned, with
no data and with an error in the DeviceCheck domain and no user info. The code
is **`DCErrorFeatureUnsupported`**, 1, which the header defines as DeviceCheck
being unavailable on this device, and which an application that reads the
documentation handles as such. The release's own path for the missing daemon is
code 0, an unknown failure that an application would take for one worth
retrying; that is the one departure from the release here, and it is recorded
in the registry.

A `nil` handler is ignored. The release, given none, would call it when the
daemon replied and end the process.

## What is not carried

`DCAppAttestService` and the attestation keys came in iOS 14 and are outside
this batch.
