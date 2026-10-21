# MusicKit for a legacy Apple platform

A module named `MusicKit`, for `armv7-apple-ios6.1.3`, so that a program written against MusicKit 26
compiles and runs on a device this port serves.

## What it is

The service is Apple's: the catalogue, the search, the previews and the library are requests to
`api.music.apple.com` over the Apple Music API. What this package adds is the surface — the model
types, the requests and the decoding — and `MusicAuthorization`.

The declarations are transcribed from `MusicKit.swiftinterface` of the 16.4 SDK, which is the SDK the
corpus measures the surface against. What each of them answers is in the table below.

## What it answers, and how

| | |
| --- | --- |
| `MusicItemID` | the catalogue's own string for an item, wrapped whole |
| `MusicItem` | what every catalogue item has: its identifier, and nothing else |
| `MusicAuthorization.currentStatus` | `.notDetermined` — a device with no Apple Music has not been asked |
| `MusicAuthorization.request()` | `.denied` — see below |
| the catalogue types, the requests, the responses | not carried yet; the next delivery |

**`MusicAuthorization` is answered as a device with no Apple Music at all**, which is every device
this port runs on: no Music app, no Apple Music account, and no way to grant one. A request therefore
answers `.denied` — the status a device that will not grant says. That is a real answer and not a
refusal: the call neither fails nor blocks, and a caller that checks the status before it plays gets
a decision it can act on. The interface's own four cases are carried with their four raw values, and
a string that is not one of the four is not a status.

## The toolchain, and why the recipe resolves the compiler

The module compiles for `armv7-apple-ios6.1.3` and **not for 6.0**: the port's Swift standard
library declares 6.1.3 as its own minimum, which is the port's own release. The compiler comes from
`swift-runtime`'s `SWIFT_EXEC` and never from a path, because the store holds two builds of swift
6.4.0 and only the patched one reaches that release — the unpatched one still refuses any target below
iOS 7.0 with *"Swift requires a minimum deployment target of iOS 7.0.0"*, which is the check
`packages/s/swift/patches/no-minimum-ios-for-a-bundled-runtime.patch` removes.

## `async`

**Measured: an `async` function compiles for `armv7-apple-ios6.1.3` under the port's flags, with no
extra flag.** The runtime the port builds carries `libswift_Concurrency.dylib` and
`_Concurrency.swiftmodule` for that release, so the async spellings are real and the catalogue
requests are written with them rather than with a completion handler that is not the API a caller of
MusicKit 26 writes. The interface guards every `async` behind `#if compiler(>=5.3) && $AsyncAwait`
precisely because the two spellings both exist.

What has **not** been measured is that an `async` call *runs* on a device at 6.1.3; that needs the
emulator or a device, and it is the first thing the next delivery does with the first catalogue
request.

## Not carried yet

The catalogue types, the search and library requests, the responses, the players and
`MusicLibrary`. The surface is 1316 rows; this is its foundation — the identity every item has and
the authorization a client asks for before it uses any of it.

## The catalogue, added

`Catalog.swift` carries the requests and the types, against the documented Apple Music API:

| | the path this sends |
| --- | --- |
| `MusicCatalogSearchRequest` | `GET /v1/catalog/{storefront}/search?term=…&types=…&limit=…&offset=…` |
| `MusicCatalogResourceRequest` | `GET /v1/catalog/{storefront}/{type}/{id}?include=…` |
| `MusicCatalogChartRequest` | `GET /v1/catalog/{storefront}/charts/{type}?limit=…` |
| `MusicDataRequest` | whatever URL the caller built, which is what the interface's own is |

and the types the service sends: `Song`, `Album`, `Artist`, `Playlist`, `Artwork`, and
`MusicItemCollection` with its `next` URL for the page after. The storefront is the one the developer
registered, and `us` is the documented default: this release has no way to ask a device its region
(`Locale.current` is iOS 10), so a storefront a caller did not name is the registered default rather
than a guess.

**Measured: the whole module - identity, authorization, token, catalogue requests and types - compiles
for `armv7-apple-ios6.1.3` under the port's flags.** The C shim builds on its own too.

### Two things the build says, written down rather than argued with

**`Sendable` is a warning, not a silence.** `URL`'s and `Artwork`'s `Sendable` conformances are gated
above 6.1.3, so every type that conforms warns that a stored property is not `Sendable` — an error
under the Swift 6 language mode, a warning here. The conformances are kept because the real surface
has them, and the warnings are the honest cost of that at this release. The alternative — dropping
`Sendable` — would be a smaller surface than a caller of MusicKit 26 writes.

**The token is minted, and measured end to end.** `MusicDeveloperToken.mint` takes what Apple hands
an application — a `.p8`, which is a PEM — reads the 32 private-scalar bytes out of the DER its body
decodes to, signs the base64url of the header and of the payload joined by a dot, and returns the
three base64url parts. The curve is `revenant@micro-ecc` through a shim that calls exactly what
`RevenantCKWebAuth.c` calls, so there is one implementation of the curve in the port, and the answer is
the raw `r || s` a JOSE verifier reads, converted from the DER micro-ecc produces with that package's
own reader.

The base64 is the module's own in both directions, because `Data.base64EncodedString(options:)` and its
inverse are marked iOS 7 by this release's Swift Foundation overlay: the port's headers lower the Objective-C
headers, where the backports put their marks, and not the Swift overlay's own. So the table is
`RevenantBase64URL`, with a decoder beside the encoder it inverts.

(a file of an earlier layout, not in the repository) is the end-to-end check: it mints a token from a key OpenSSL
made and asks OpenSSL to verify the signature over the first two parts joined by a dot, which is what a
JOSE verifier does. The last line it prints is `OpenSSL  : Verified OK`. Three mutations of the module
turn it red — the two ways of getting the token's shape wrong, and a signing input one byte off — and
that check could not run at all until this round, which is why the first version of this section said
the token could not be minted: the run never reached its own checker.

**What that check is not**: a device run. The module is built for the host there, and no emulator has
run it, so "this mints a token on 6.1.3" is measured on a Mac and nowhere else. A token minted
elsewhere is the other of the two documented ways to authenticate the API, and needs nothing of this
port but the request.
