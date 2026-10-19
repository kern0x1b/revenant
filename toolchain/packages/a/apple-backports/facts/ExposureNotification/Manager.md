# `ENManager` and `ENErrorDomain`, iOS 12.5, with 13.5 and 14.4 members

`Foundation/ENManager.m`, `ENManagerExposureInfo13.m`, `ENManagerPreAuthorized14.m`, `ENErrorDomain.m`.

## What this release can answer, and why that is the whole of it

Exposure Notification is a system service that arrived in iOS 12.5. It needs three things this release
does not have:

1. **The framework.** 6.1.3 carries no EN class and no EN symbol -- no class in its ObjC inventory whose
   name begins EN, no symbol in its export trie.
2. **The entitlement and the per-device authorization** behind the service, which no port can grant
   itself.
3. **The Bluetooth Low Energy subsystem** the service broadcasts over, which iOS 6 does not run at all.
   `ENManager.h` says so itself, twice: "Bluetooth is required for Exposure Notification" under
   `ENStatusBluetoothOff`, and "Exposure Notification is a system service and can use Bluetooth in
   situations when apps cannot".

So there is no detection to perform and no key to hand out, and every member that needs the service
answers what Apple's own framework answers on a device that cannot do Exposure Notification at all:

| member | answer |
| --- | --- |
| `-exposureNotificationStatus` | `ENStatusUnauthorized` (6) |
| `+authorizationStatus` | `ENAuthorizationStatusNotAuthorized` (2) |
| `-exposureNotificationEnabled` | `NO` |
| every completion handler | `ENErrorCodeUnsupported` (5), or `ENErrorCodeInvalidated` (6) after `-invalidate` |

`ENStatus` has no "unsupported" case. Its own header documents `ENStatusUnauthorized` as "Exposure
Notification is not available due to insufficient authorization", which is what a release with neither the
service nor the authorization is; and `ENAuthorizationStatusNotAuthorized` as "This app is not authorized
to use Exposure Notification". Both enum values and every `ENErrorCode` case are the SDK's own: 16.4's
`ENCommon.h` writes each one out with its number and a one-line description, and this file uses those
words.

## `-invalidate` is the one member with behaviour that needs no service

The header promises it precisely: "The invalidation handler will be invoked exactly once even if
`invalidate` is called multiple times", "No handlers will be invoked after that", "The invalidation
handler will be invoked exactly once", "All strong references are cleared when invalidation completes to
break potential retain cycles", and "This property is cleared before it's invoked to break potential
retain cycles". So `-invalidate` marks the object unusable, clears `invalidationHandler` and
`activityHandler`, and calls the handler once; a second call does nothing. The object also calls it from
`-dealloc`, so an application that drops its last `ENManager` without calling `-invalidate` still gets the
one invocation the header promises, from the only place left that can give it.

## `-dispatchQueue`

The header: "Dispatch queue to invoke handlers on. Defaults to the main queue." The property is carried
because it is what the header declares and a caller may set it. The completion handlers are called where
they are called rather than dispatched onto it, which is what a handler that runs before the call returns
is; the queue is what a caller reads back.

## `ENErrorDomain`

`ENCommon.h:64` declares `extern NSErrorDomain const ENErrorDomain;` and gives no value, so there is
nothing in a header to read. It was measured out of a release that has it, with charon's own reader:

```
$ printf 'ENErrorDomain\t8\tp\ts\n' > symbols.txt
$ CHARON_ROOT=$PWD xmake l tools/corpus/cache-value.lua ~/.charon/dyld/16.0/dyld_shared_cache_arm64e symbols.txt
#cache	arm64e	8
ENErrorDomain	/System/Library/Frameworks/ExposureNotification.framework/ExposureNotification	0x20e5acab8	a888db1402000800	349931688	2251808753551528	1.1125413461344081e-308	0x214db88a8	ENErrorDomain	8	8
```

The domain string is `ENErrorDomain`. ExposureNotification arrived in 12.5 and the 16.0 arm64e cache is
the oldest one on this machine that has the framework (`~/.charon/dyld/` lists 12.0 and 16.0 but no
12.5-15.x), which is what makes that cache the measurement rather than a recollection.

There is no `ExposureNotification.framework` in any SDK installed here
(`/Library/Developer/CommandLineTools/SDKs/MacOSX{26.5,27}.sdk/System/Library/Frameworks/` has no such
directory), so this Mac's own frameworks cannot answer any of this framework's questions. The cache is the
only release-side oracle on this machine that has ExposureNotification in it.
