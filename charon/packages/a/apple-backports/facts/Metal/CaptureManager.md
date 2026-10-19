# MTLCaptureManager and MTLCaptureDescriptor, iOS 11 / 13

Part of the Tier 2 Metal/MetalKit verdict. `MTLCaptureManager` is process-wide GPU trace tooling;
its scopes and its manager object are ordinary Objective-C objects, not GPU work themselves - only
actually starting a capture needs a backend this port does not have.

## What the port does

`+sharedCaptureManager` gives a real per-process singleton (a private `initCharon` avoids the
header's own `-init` being marked `API_UNAVAILABLE`, matching the pattern the real class uses).
`-newCaptureScopeWithDevice:`/`-newCaptureScopeWithCommandQueue:` give a real object conforming to
`MTLCaptureScope`: `-beginScope`/`-endScope` are no-ops (there is nothing to bracket), `label`,
`device` and `commandQueue` hold what they were given. `-supportsDestination:` always answers `NO`.
`-startCaptureWithDescriptor:error:` refuses with `MTLCaptureErrorNotSupported` in
`MTLCaptureErrorDomain` - the header's own documented meaning for "capturing is not supported" -
rather than a silent success or a generic error. The three deprecated
`-startCaptureWithDevice:`/`-startCaptureWithCommandQueue:`/`-startCaptureWithScope:` and
`-stopCapture` are no-ops; `-isCapturing` always answers `NO`.

`MTLCaptureDescriptor.captureObject`/`.destination`/`.outputURL` hold what is set, and `-copyWithZone:`
deep-copies them.

## What is the actual wall

There is no GPU trace capture backend in this port at all: `CharonMetalDevice` runs over OpenGL ES
2.0, and nothing records or exports the Xcode GPU trace format this class's whole purpose is to
produce. `-startCaptureWithDescriptor:error:`'s refusal names this precisely rather than leaving
`isCapturing` stuck at `YES` or silently doing nothing while claiming success.
