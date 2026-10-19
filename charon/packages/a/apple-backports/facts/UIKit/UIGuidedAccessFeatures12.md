# Configuring the accessibility features of a Single App Mode session, iOS 12.2

`UIGuidedAccessConfigureAccessibilityFeatures()` and the error domain its failures are reported in,
both in `UIKit/UIKitConstants134.m`.

## The function

`UIGuidedAccessConfigureAccessibilityFeatures(features, enabled, completion)` changes which
accessibility features a Single App Mode session allows, for a kiosk deployment. Its own header
describes who may call it (SDK 26.2, `UIGuidedAccess.h:78-90`):

> Applications that are locked into Guided Access via a Single App Mode profile are granted the
> ability to configure certain accessibility features, to support kiosk deployments.

And the error enumeration names the case that is exactly a device without that lock
(SDK 26.2, `UIGuidedAccess.h:17-19`):

> The application is not authorized to perform the requested action. For example, it may have
> requested a configuration change but is not locked into Single App Mode via a configuration
> profile.

iOS 6.1.3 has no Single App Mode profile and no way to be given one, so the request is not
authorized and the completion is called with `success` NO and an `NSError` in
`UIGuidedAccessErrorDomain` whose code is `UIGuidedAccessErrorPermissionDenied` - the header's own
example, not a choice. `UIGuidedAccessErrorFailed` is the generic case, and a device that cannot do
the thing at all is not a device on which it failed halfway.

The completion is called from the next turn of the main queue, not from inside the call: the
release's own completion is not called from inside the request either, and an application that reads
its own state right after asking must not find it already changed. A nil completion is not called.

The `features` mask is not consulted, for the same reason nothing else about the request is: there
is no session whose allowed features it could be.

## The error domain's value

`UIGuidedAccessErrorDomain` is the `NSErrorDomain` the failure is reported in, so its value is
carried rather than left out - an `NSError` with no domain is not an `NSError` the caller can read.
Read out of a real dyld shared cache with `tools/corpus/cache-value.lua`, the oldest held release
that exports the symbol first, and it is the same in every cache checked:

| release | cache | image | the value |
| --- | --- | --- | --- |
| 13.4 | `dyld_shared_cache_arm64` | `/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore` | `UIGuidedAccessErrorDomain` |
| 16.0 | `dyld_shared_cache_arm64e` | `/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore` | `UIGuidedAccessErrorDomain` |
| 18.0 | `dyld_shared_cache_arm64e` | `/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore` | `UIGuidedAccessErrorDomain` |

The constant's value is its own name, so the read is also its own check: a reader that followed a
neighbouring object would name a different string, and this one names itself in every cache.

## Why the two are in one object

The function reads the domain, and an object is kept or reexported as a whole. One object carries
one release, and both of these are iOS 12.2 API whose first held exporting release is 13.4, so they
sit in the same object and move together in every band. A function in one object calling a constant
in another breaks in exactly the bands where the two land on opposite sides of that split
(`charon/AGENTS.md`, "A C function shared between backport files").
