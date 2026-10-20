# AAAttribution, iOS 14.3

`AAAttribution` is one class and one method: `+attributionTokenWithError:` asks Apple's attribution
service for a token that ties an install of an application to the advertisement that brought it in.
The token is not computed on the device. It is minted by Apple's own service, over the network,
against an application that is registered with it and carries AdServices.

## The seam

That service is a wall this port cannot reach, in the sense COORDINATION §2 allows: it is a remote
Apple service, it issues tokens only for a release that carries AdServices, and iOS 6.1.3 does not.
The API surface is still here, in full; the refusal happens only at the seam, and it is the
framework's own documented answer for this case rather than an invented one.

`AAAttributionErrorCodePlatformNotSupported` is documented as "attributionTokenWithError: is unable
to provide a token because of an unsupported operating system". iOS 6.1.3 is an operating system
AdServices does not support, and none of the other two codes would be true: the network is
available (so not `...NetworkError`) and nothing internal failed (so not `...InternalError`).

## What the port answers

- `+attributionTokenWithError:` returns `nil`. When the error out-parameter is not NULL it is set to
  an `NSError` in `AAAttributionErrorDomain` with code `AAAttributionErrorCodePlatformNotSupported`
  (3). A nil out-parameter is allowed and nothing is written.
- The description is this port's own and says the fact: "Attribution is not available on this
  version of iOS." It is deliberately **not** the host's text, which reads "Attribution services are
  only available on iOS and iPadOS" — on this device it *is* iOS, so that sentence would be false.
- `AAAttributionErrorDomain` is `com.apple.ap.adservices.attributionError`, the text AdServices
  itself gives it.

## What it was held to

The host's own AdServices, under MacOSX.sdk, is a platform the service does not support either.
Measured there:

- `+attributionTokenWithError:` returns `nil`;
- the error's domain is `com.apple.ap.adservices.attributionError`, its code is `3`
  (`AAAttributionErrorCodePlatformNotSupported`), and its localized description is "Attribution
  services are only available on iOS and iPadOS.";
- the constant `AAAttributionErrorDomain` is the same string, so the port's domain is Apple's own
  and not a spelling of it.

The port keeps the domain and the code of the host and states the fact in its own words.
(`tests/backports/host/adservices` holds the host side of that measurement.)

The domain's text was also read out of a real cache rather than taken from the header:
`tools/corpus/cache-value.lua` over the arm64e shared cache of iOS 18.0, through the symbol
`_AAAttributionErrorDomain` of AdServices, which reads `com.apple.ap.adservices.attributionError`.

## What it does not do

It mints nothing and fakes nothing: there is no token, no partial token and no substituted value.
An application that requires a token to go on gets `nil` and the error that says why, which is the
only honest answer a device outside the service's reach can give.
