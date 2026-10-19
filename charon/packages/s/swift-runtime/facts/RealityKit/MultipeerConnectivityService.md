# MultipeerConnectivity: what exists to build on, and what the block really is

Measured 2026-09-28, band `cb2dd0bd`, before writing any of it.

## The reuse search: one reimplementation, over a different substrate

Searched GitHub's repository index twice — `multipeerconnectivity bonjour`, and
`MCSession reimplementation OR shim OR dns-sd`, sorted by stars. The hits:

| repository | what it is | usable here? |
| --- | --- | --- |
| **`security-union/Stormo`** — "Drop-in replacement for Apple's MultipeerConnectivity — QUIC over Network.framework, AWDL-capable, works on iOS 26" (MIT, 2026-07-26) | **a reimplementation** | no, and the reason matters: it is QUIC over Network.framework and AWDL, and this release has neither — the port's own `Network` library is a BSD-socket floor (`facts/Network/NWFloor.md`) and AWDL is a radio the release has no use for. It is also written for an SDK with a Swift MultipeerConnectivity overlay, which this one does not ship |
| `shrtlist/MCSessionP2P` (61★, Apache-2.0) | a consumer of `MCSession` | no — it *uses* the framework |
| `Olib-AI/ConnectionPool` (10★, MIT) | mesh library on top of MultipeerConnectivity and a WebSocket relay | no — a consumer |
| `1amageek/swift-peer-connectivity` (4★) | "app-facing Swift API for peer discovery across libp2p, Network.framework, Bonjour, and MultipeerConnectivity" | no — a wrapper |
| `baydet/MPCF_Multistream_Test`, `yohannes/Selfie-Share`, `CG-Victor/Project-25-Selfie-Share`, `submariner100/Project25`, `Timardo/MCSessions` (WIP, Java), `ItsRaelx/McSession` (Python) | samples and bindings | no |

So: **named — `security-union/Stormo` — and no Bonjour/DNS-SD reimplementation exists.** Every route to Bonjour here is Apple's own `NSNetService`, which the release *does* have (Foundation, iOS 2.0), so a MultipeerConnectivity over `NSNetService` is the port's own arithmetic and there is nothing open to lift.

## The block is smaller than the first report said, and split across two ledgers

- `coordination/corpus/ledger/MultipeerConnectivity.tsv` — **71 rows**, the framework: `MCPeerID`, `MCSession`, `MCNearbyServiceAdvertiser`, `MCNearbyServiceBrowser`, `MCBrowserViewController`, `MCAdvertiserAssistant`, the enums, the error codes and 17 constants. That is the **Objective-C** backport, in `packages/a/apple-backports/`, over `NSNetService` — and it is not this band's ledger.
- `coordination/corpus/ledger/RealityKit.tsv` — **11 rows**, `MultipeerConnectivityService` and its members, which *is* this band's: the RealityKit wrapper over an `MCSession`, and it cannot be written until the 71 exist, because `init(session:)` and `session` are the whole of it.

The 26.2 SDK ships MultipeerConnectivity with **a `module.modulemap` and no Swift overlay** (measured:
`Modules/` holds only `module.modulemap`), so the framework is Objective-C and belongs with the
backports, not with the Swift overlays in this package.

## What this band can start now

Nothing that needs a session. `MultipeerConnectivityService` is eleven rows of a wrapper, and nine of
them are methods that take an `MCPeerID` — a type that does not exist until the framework's 71 rows are
carried. Writing the wrapper first would be a declaration standing in for a type the port has not got,
which is the thing the registry's `absent` rows are for.
