# The HomeKit model

iOS 8.0's HomeKit is an object graph: a home holds rooms, zones, users, service groups, accessories,
triggers and action sets; an accessory holds services; a service holds characteristics; an action set
holds actions. The port implements that graph, and the graph is a real store rather than a cache of
what the process happens to be holding — `RevenantHomeKitStore.m`, one property list per table under the
application's own Application Support directory, written atomically when a table changes. A name
changed through `-updateName:completionHandler:` is on disk before the handler is called; a home
added through `-addHomeWithName:completionHandler:` is there for the next launch.

## Where the release's own state ends and the port's answer begins

iOS 6 runs no home hub, no homekitd and no accessories daemon, so there is no system service to ask
for a home graph, and the port keeps it itself. Three of the answers follow from that and are worth
naming separately, because each is a place where a quieter answer would be a lie:

- **`HMHomeManager.authorizationStatus` is `HMHomeManagerAuthorizationStatusDetermined`.** The status
  answers whether this process may read the homes. It may: the graph is the application's own store,
  which no other application can reach, and there is nothing for the system to refuse.
- **`HMHomeAccessControl.administrator` is `YES`.** For the same reason. Answering `NO` would tell an
  application that its own store is writable by somebody else, and an application that believes it
  would stop doing the one thing it is entitled to do.
- **`HMHome.homeHubState` is `HMHomeHubStateNotAvailable` and `HMEventTrigger.triggerActivationState` is
  `HMEventTriggerActivationStateDeactivated`.** Both are the states a home with no hub answers. A home
  hub is the Apple TV or iPad that runs a home away from home, and this release has neither in the
  role; an event trigger fires when the hub is there to run it.

## What needs an accessory, and what it answers

The accessory's own values are not in the graph and are not invented from it. Without a HAP session
the port answers the error the release documents:

| call | answer |
| --- | --- |
| `-readValueWithCompletionHandler:` | `HMErrorCodeAccessoryNotReachable` |
| `-writeValue:completionHandler:` on a characteristic that is not writable | `HMErrorCodeReadOnlyCharacteristic` |
| `-writeValue:completionHandler:` otherwise | `HMErrorCodeAccessoryNotReachable` |
| `-enableNotification:completionHandler:` on a characteristic that does not notify | `HMErrorCodeNotificationNotSupported` |
| `-enableNotification:completionHandler:` otherwise | `HMErrorCodeAccessoryNotReachable` |
| `-updateAuthorizationData:completionHandler:` on a characteristic that takes none | `HMErrorCodeOperationNotSupported` |
| `-updateAuthorizationData:completionHandler:` otherwise | `HMErrorCodeInvalidOrMissingAuthorizationData` |
| `-identifyWithCompletionHandler:` | `HMErrorCodeAccessoryNotReachable` |
| `-[HMHome addAccessory:completionHandler:]` | `HMErrorCodeAccessoryPairingFailed`, and the graph is left exactly as it was |

`HMAccessory.reachable` is `NO` for the same reason, and that one is a property rather than a method:
the graph does not hold reachability, because an accessory that was reachable when the last session
ended is not reachable now, and a `YES` an application acted on would be a lie.

The errors are checked against the graph first, in that order: a write to a read-only characteristic
answers the read-only error whether or not there is a session, because that answer is true
regardless. Only when the graph agrees the call is allowed does the missing session decide.

## What is refused, and why

Three additions are refused with the code the release uses rather than carried with a substitute
behaviour, because each would change what an application believes about its own graph:

- `-addRoomWithName:`, `-addZoneWithName:` and `-addServiceGroupWithName:` answer
  `HMErrorCodeObjectWithSimilarNameExistsInHome` for a name the home already uses among those three,
  and the home manager answers `HMErrorCodeHomeWithSimilarNameExists` for a second home of that name.
- `-updateFireDate:completionHandler:` answers `HMErrorCodeFireDateInPast` for a date in the past,
  because a trigger that fires where it cannot is one that will never fire again.
- `-removeUser:` refuses to take the home's last user, with `HMErrorCodeCannotRemoveBuiltinActionSet` —
  the code the release uses for an object a home will not do without.

## Where an object is a window, and how it stays one

Every model object holds its own identifier in an ivar and its own fields in the store's record under
that identifier, and the two cannot disagree because the identifier is what the record is keyed by.
The port's own way back in is a C function per class (`RevenantHomeKitRoom`, `RevenantHomeKitHome` and the
rest) defined in the file that defines the class, and a class extension carrying the identity and the
edge back to the owner. Neither is a row of the surface: `modules/apple/backports.lua` filters a
symbol whose name starts with `revenant` out of what an object is weighed for, and a class extension is
part of the class's own implementation.

One cycle in the graph is real and the store breaks it: `HMAccessory.home` and `HMHome.accessories`,
`HMRoom.accessories` and `HMAccessory.room` each need the other. The home's own record holds the
ordering and the membership, so the membership is read from there and written there, and there is
exactly one place each edge lives.

## What was measured, and what was reasoned

Measured: every constant the model compares against (`facts/HomeKit/HMConstants.md`), and the release
each class and each member arrived in (`tools/release-split.lua`, which walks the real cache ladder
and is the measurement the band machinery places objects by).

Reasoned, and recorded as such: which error a call answers at this seam. Each is the error the
release documents for the same condition with a real accessory absent, and each is a one-line reading
of the header's own contract — not a behaviour observed on a device, because there is no HAP accessory
on one. A device run with a real accessory is what would confirm them, and it has not happened.

## A correction the compiler forced, and one I got wrong

**HomeKit's `uniqueIdentifier` family is an `NSUUID`, not a string.** `HMRoom.h:37`, `HMZone.h:41` and
`HMUser.h:31` all say `@property (readonly, copy) NSUUID *uniqueIdentifier`. Every graph edge is keyed by
a string, so the accessors convert at the edge -- `RevenantHomeKitUUIDString` to write one, `RevenantHomeKitUUID`
to read one back -- and the value an application reads is the UUID Apple's own type says it is. This
was found by the compiler, not by reading the header first, and it is the kind of thing a port that
writes from the memory of an API gets wrong.

**I claimed a header defect that does not exist, and it is retracted here.** Having seen an `NSUUID *`
where a string was expected, I reported that the port's Foundation headers declare `-[NSUUID UUIDString]`
returning `NSUUID *`, and said it affected every band. It does not. The declaration is:

    $SDK/System/Library/Frameworks/Foundation.framework/Headers/NSUUID.h:24
      - (nullable instancetype)initWithUUIDString:(NSString *)string;
    $SDK/System/Library/Frameworks/Foundation.framework/Headers/NSUUID.h:36
      @property (readonly, copy) NSString *UUIDString;

where `$SDK` is
`~/.xmake/packages/i/iphoneos-sdk/16.4/cccc080d0cbe42c2a85b1369aba6e290/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk`
-- the SDK the build compiles against, and the same 26.2 header agrees. A two-line file using both
selectors compiles clean at `-target armv7-apple-ios6.1.3`. There is no port header `NSUUID.h` in the
include path. The `NSUUID *` came from HomeKit's own header, and the rest was me not reading the
diagnostic to its source. Nothing here is a defect for the coordinator to route.

## Not carried, and what that costs

- **`HMAccessoryBrowser`, `HMAccessoryProfile`, `HMCameraProfile` and the whole camera surface.**
  These are discovery and the accessory's own stream; both need a HAP transport, which the next part
  of this work carries. They are registered `absent` with that reason.
- **`HMAccessorySetupPayload`, `HMAccessoryOwnershipToken`, `HMAccessorySetupManager`,
  `HMAccessorySetupRequest`, `HMAccessorySetupResult`** — a QR code read out of the accessory and a
  pair-setup, the same seam.
- **`HMNetworkConfigurationProfile`** — the system's own knowledge of what a home's accessories are
  on.
- **`HMAccessoryCategory.localizedDescription`.** It is a localized string: the value is the release's
  localization table's, for the running language. The host has no HomeKit in its dyld cache and no
  release on this machine ships a HomeKit resource bundle this port can read, so there is nothing to
  read, and a name written here would be one no release ships. `-categoryType` is carried, with the
  HAP UUID. See `HMAccessoryCategory.md`.
