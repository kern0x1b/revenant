# ATTrackingManager, iOS 14

`ATTrackingManager` is how an application asks the owner for permission to track the user across
apps, and asks what the answer is. It arrived with iOS 14, on a release that runs a system service
(`tccd`) to record the answer per bundle identifier, puts a prompt up in front of the owner, and a
privacy setting the owner can change afterwards.

## What the devices this port runs on are

An iPhone 4S and an iPad 2 running iOS 6.1.3 have no such system at all. Measured, not assumed:

- the armv7 shared cache of iOS 6.1.3 carries **AdSupport** with `ASIdentifierManager`, and its
  selector list has `advertisingIdentifier` and **no** `trackingEnabled`: the release hands the
  advertising identifier out and has no way to say that tracking is turned off, because the setting
  that turns it off (`Limit Ad Tracking`, iOS 7) and the prompt that asks for it do not exist yet.
- `AppTrackingTransparency.framework` is not in that cache, nor is `tccd`.

So nothing on this release ever decides a tracking status, and nothing restricts the identifier. The
two questions are answered as a platform without the system answers them.

## What the port answers

- `+trackingAuthorizationStatus` is `ATTrackingManagerAuthorizationStatusNotDetermined`, always. It
  is the honest value and not a softened one: the owner was never asked, so no decision of theirs
  exists to report. It is deliberately *not* `...Authorized`, which would claim a permission nobody
  granted, and *not* `...Denied`, which would misdescribe a release that permits tracking.
- `+requestTrackingAuthorizationWithCompletionHandler:` calls the handler once with
  `ATTrackingManagerAuthorizationStatusNotDetermined`, on the thread that asked, before the call
  returns. A nil handler is allowed. A second request calls it again the same way; nothing is
  remembered between requests, because there is nothing to remember.
- `+new` and `-init` are `NS_UNAVAILABLE` in the header, as they are in Apple's own framework, and
  are not implemented here either: an application cannot name them, and at run time they are
  NSObject's.

The answer is not a prompt and not a refusal. An application that shows its own "would you like to
be tracked" screen still can, and the identifier is still there to be read.

## What it was held to

The host's own AppTrackingTransparency, under MacOSX.sdk, is a platform that does not run the
system either, and the header says so of macOS: "If you call `ATTrackingManager.trackingAuthorizationStatus`
in macOS, the result is always `...notDetermined`". Measured on the host:

- `+trackingAuthorizationStatus` answers `0`, notDetermined;
- `+requestTrackingAuthorizationWithCompletionHandler:` calls the handler with `0` **on the main
  thread, inside the call** — the probe printed the handler's line before the line after the call —
  and a second request calls it again, also inside the call.

The port does exactly that, which is the same behaviour on a platform with the framework and a
platform without it: a decision that does not exist is reported as not made, at once, on the thread
that asked. (`tests/backports/host/apptracking` holds the host side of that measurement.)

## What it does not do

It does not track anything, does not restrict anything and does not put a prompt up. The identifier
of the release stays reachable through AdSupport, unchanged: nothing here stands between an
application and the advertising identifier, because on this release there is no setting that could
keep it from one.
