# HMAccessory

The two 10.0 members that say where an accessory is. Both are declared on the 8.0 class, so both live in
`HMAccessoryHome10_0.m`, which is of 10.0 alone.

## `-home`, of 10.0 — carried

`HMAccessory.h:37`, quoted:

```objc
@property (nullable, nonatomic, readonly, weak) HMHome *home
    API_AVAILABLE(ios(10.0), watchos(3.0), tvos(10.0), macCatalyst(14.0)) API_UNAVAILABLE(macos);
```

So: **nullable**, **weak**, **readonly**, and of **10.0**, unavailable on macOS. The contract check
asserts each of those from this line — the selector's presence in the library, that it answers an
`HMHome *`, that an accessory with no home identifier answers nil rather than a home, and that the answer
for one that has an identifier is the home that identifier names, compared against
`CharonHomeKitHome(identifier)`, the graph's own entry point.

The port's accessory already carries the identifier of its home in `charon_homeIdentifier`, the same
field the home graph's entry points are given, so the answer reuses the graph and there is no second way
to reach a home in this library.

## `-cameraProfiles`, of 10.0 — carried

`HMAccessory+Camera.h:28`, quoted:

```objc
@property (nullable, nonatomic, readonly, copy) NSArray<HMCameraProfile *> *cameraProfiles
    API_AVAILABLE(ios(10.0), watchos(3.0), tvos(10.0), macCatalyst(14.0)) API_UNAVAILABLE(macos);
```

The attribute difference from `home` above is real and the check compares each of them: `cameraProfiles` is
**copy** where `home` is **weak**, and it is an `NSArray` where `home` is a single object.

The element type is `HMCameraProfile`, which this port carries in `HMAccessoryProfile10_0.m` of the same
release, so the answer's type exists and the accessor is written with it. It is **not** marked `absent` in
the registry: `absent` means the release does not export the member, and the 10.0 header declares it. The
row was flipped to `implemented` in place, keeping one spelling of the API — a second row in the selector
form would be one API in two spellings, which the light guard refuses and which would be carried into the port's headers and
lowered together.

The profiles are the ones the graph holds for this accessory, read from the accessory's own record through
the graph's own list field — the same helper a home's rooms and zones are read with — and each is built by
`HMAccessoryProfile`'s own graph initialiser, so there is no second way to make a profile in this library.
An accessory that publishes none answers an **empty array**: the header's nullable allows it, and an array
is what the property is, so a caller can iterate the answer without first asking whether there is one.

## What is not checked here, and why

There is **no host HomeKit on this machine** to ask: no `HomeKit.framework` exists in any macOS SDK here,
so nothing can be sent a message, and 52 of the SDK's 62 HomeKit headers mark themselves
`API_UNAVAILABLE(macos)`. So the checks for these rows are the header's declared contract, plus a selector
presence count against the 12.0 and 16.0 arm64 caches in `~/.charon/dyld` — which confirms a **name**
first appeared at a release, and is **not** a behaviour oracle. Both facts are recorded in the registry
rows' `source`, and the standing limit is in `coordination/crutches.md`.

A measurement worth keeping, because it contradicts a comment already in this library: the port's
`HMAccessoryCategory` file says "The host has no HomeKit in its dyld cache", and that is not right. By
substring count with a boundary, `HMAccessory` is in the held arm64 caches of 8.0, 9.0, 11.0 and 12.0.
What is absent is a *host framework to link*, not a HomeKit in the caches. That comment overstates the
gap, and this file is the place the correction belongs.
