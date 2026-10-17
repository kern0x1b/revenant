# UNLocationNotificationTrigger

Introduced in iOS 10.0. When a notification fires because the device entered or
left a region, and carried on iOS 6 as a region CoreLocation watches, since the
release has been able to watch one since iPhone OS 4.0.

Sources: the UserNotifications headers of the iPhoneOS 16.4 SDK the port is
compiled against, for the API and for the sentence that says when the trigger
fires; the armv7 caches of iOS 4.3 and of iOS 6.1.3 for what the releases carry;
the name index over all 50 held rungs for the whole ladder.

## What it is

```objc
@interface UNLocationNotificationTrigger : UNNotificationTrigger
@property (NS_NONATOMIC_IOSONLY, readonly, copy) CLRegion *region;
+ (instancetype)triggerWithRegion:(CLRegion *)region repeats:(BOOL)repeats API_AVAILABLE(watchos(8.0));
@end
```

`UNNotificationTrigger.h` of the iPhoneOS 16.4 SDK, line 53, in its first
sentence, is what the release answers:

> UNLocationNotificationTrigger can be scheduled on the device to notify when the
> user enters or leaves a geographic region. The identifier on CLRegion must be
> unique. Scheduling multiple UNNotificationRequests with different regions
> containing the same identifier will result in undefined behavior. The number of
> UNLocationNotificationTriggers that may be scheduled by an application at any
> one time is limited by the system. Applications must have "when-in-use"
> authorization through CoreLocation.

Two of those are the port's own rules: the region identifier is what a crossing
is reported under, so two regions may not share one, and the release counts the
regions it watches. It inherits `-repeats` from `UNNotificationTrigger` and adds
no `nextTriggerDate:` of its own, so a location trigger has no date - which is
why a request carrying one is not scheduled at all.

`first-rung.lua triggerWithRegion:repeats: UNSLocationMonitor nextTriggerDate`
answers `10.0.1` for each of the three, so the API and the trigger arrived
together, and on iOS 10 the region is watched by `UNSLocationMonitor`, in
`UserNotificationsServer`, which the facts page of `UNUserNotificationCenter`
names. `UNSLocationTrigger` answers `NONE`: there is no class of that name.

## What iOS 6 has to watch a region with

`$ xmake l tools/cache-index/first-rung.lua --rungs initCircularRegionWithCenter:radius:identifier:`

```
4.0,4.3,4.3.5,5.0,5.1.1,6.0,6.0.2,6.1,6.1.3,6.1.4,6.1.6,7.0,7.0.1,7.0.6,7.1,7.1.1,7.1.2,
8.0,8.0.2,8.1,8.1.1,8.1.2,8.1.3,8.2,8.3,8.4.1,9.0,9.0.2,9.1,9.2,9.2.1,9.3,9.3.5,9.3.6,10.0.1,
10.1.1,10.2,10.2.1,10.3,10.3.1,10.3.2,10.3.3,10.3.4,11.0,12.0,16.0,18.0
```

**Every held rung from 4.0 to 18.0 carries it**, 6.1.3 among them, so a release
before `CLCircularRegion` (7.0) constructs its region the older way and the port
never needs the newer class. With it, `first-rung.lua` reads `CLRegion` at 4.0,
`startMonitoringForRegion:` at 5.0, `stopMonitoringForRegion:` and
`monitoredRegions` at 4.0, `regionMonitoringEnabled` at 4.0 and
`locationManager:didEnterRegion:` and `locationManager:didExitRegion:` at 4.0 -
the two callbacks the trigger's sentence above needs.

`$HOME/.charon/dyld/6.1.3/selectors_armv7.txt`, the selector set of the armv7
cache of 6.1.3, carries each of them - `initCircularRegionWithCenter:radius:identifier:`,
`containsCoordinate:`, `maximumRegionMonitoringDistance`, `authorizationStatus`,
`locationServicesEnabled`, `locationServicesApproved`, `monitoredRegions`,
`regionMonitoringEnabled`, `startMonitoringForRegion:`, `stopMonitoringForRegion:`
all answer 1. (`initWithCenter:radius:` answers 0 and `notifyOnEntry`,
`notifyOnExit`, `initWithCenter:radius:identifier:` answer 0: those are the 7.0
spellings.)

The class-scoped reading of the low band end, which is a dump of 7187 classes in
the armv7 cache of iPhone OS 4.3:

```
$ python3 -c "import json; c=json.load(open('$HOME/.charon/dyld/4.3/classes_armv7.json'))['classes']; \
    [print(k, c[k]['instance'] if k in c else 'ABSENT') for k in \
     ('CLRegion','CLLocationManager','CLCircularRegion','CLBeaconRegion')]"
CLRegion             center, clientRegion, containsCoordinate:, copyWithZone:, dealloc, description,
                     encodeWithCoder:, identifier, initCircularRegionWithCenter:radius:identifier:,
                     initWithClientRegion:, initWithCoder:, radius
CLLocationManager    ..., maximumRegionMonitoringDistance, monitoredRegions, setDelegate:,
                     startMonitoringForRegion:desiredAccuracy:, stopMonitoringForRegion:, ...,
                     class: _authorizationStatus, authorizationStatus, headingAvailable,
                     locationServicesEnabled, locationServicesEnabled:, regionMonitoringAvailable,
                     regionMonitoringEnabled, setLocationServicesEnabled:, sharedManager
CLCircularRegion     ABSENT
CLBeaconRegion       ABSENT
```

The control is in that same read: 7187 classes came out of it, `CLRegion` and
`CLLocationManager` are two of them, and the two region subclasses a reader would
mistake for the older ones are not - so the absence is the release's, not the
reader's. `CLCircularRegion` and `CLBeaconRegion` both arrive at 7.0
(`first-rung.lua`), which is why the port takes the plain `CLRegion` the trigger's
own property is typed as.

## What the port does with it

| iOS 10 | on iOS 6 |
|---|---|
| `+triggerWithRegion:repeats:` | asserts a region, keeps a copy of it and the repeats beside it |
| `-region` | the region as it was given, copied |
| a request carrying one is scheduled in the daemon's repository | the request is kept under its region identifier, and `-[CLLocationManager startMonitoringForRegion:]` is called once for the region |
| the daemon presents it when `UNSLocationMonitor` sees a crossing | CoreLocation's own `locationManager:didEnterRegion:` and `locationManager:didExitRegion:` build the notification and hand it to `-[UIApplication presentLocalNotificationNow:]`, which is the same path a request with no trigger takes, so the centre's delegate hears of it as it hears of any other |
| a trigger that does not repeat fires once | the request is dropped and its region stopped after the first crossing, so it does not fire again |
| the request is pending until it fires | it is in `-getPendingNotificationRequestsWithCompletionHandler:`, which takes it from the monitor as well as from `-scheduledLocalNotifications`, and `-removePendingNotificationRequestsWithIdentifiers:` and `-removeAllPendingNotificationRequests` stop the regions as well as cancel the dates |
| a device that cannot watch a region refuses the request | `+[CLLocationManager regionMonitoringAvailable]` answers NO and the request is refused with `NSCocoaErrorDomain` `NSFeatureUnsupportedError` and a reason naming the release, as every other request the release cannot keep is |
| a region the system will not watch is refused by the daemon | `locationManager:monitoringDidFailForRegion:withError:` says so once, and the request stays pending rather than being silently dropped |

The region's radius is left to CoreLocation, which is what clamps it, and the
region identifier is required because it is what a crossing is reported under:
two regions sharing one identifier would make one crossing fire both, which the
SDK's own sentence calls undefined.

## How it is held

`tests/backports/device/notifications.m`: a region is built the way a 6.x caller
builds one, the trigger keeps it and its repeats, a request carrying it is added
and refused by nothing, comes back pending with the region and the content it was
added with, and iOS 6 is given nothing to schedule for it.

What the run does **not** cover, and what is therefore reasoned rather than
measured: the crossing itself. It needs the device to move across the edge of a
100 km region around 0, 0, and no release can be asked to do that from a bench.
What is measured is that the port hands CoreLocation the region, that it presents
the notification when CoreLocation says the device crossed, and that the rest of
the path - the notification, the delegate, the badge - is the port's existing and
already-held one.

## `release-split`

```
$ .agent-work/plan-and-analysis/d5-un-r10/compile.sh "$PWD/packages/a/apple-backports" \
      UIKit/UNLocationNotificationTrigger10.m <objects> 6.0
$ xmake l tools/release-split.lua <objects> <report> "$SDK"
release-split: clean, every object file's symbols first-appear in one release (4 files, 23 symbols, 50 releases checked)
UNLocationNotificationTrigger10.o  _OBJC_CLASS_$_UNLocationNotificationTrigger     10.0.1
UNLocationNotificationTrigger10.o  _OBJC_METACLASS_$_UNLocationNotificationTrigger 10.0.1
```

The helper classes in that object are named `Charon*`, which is what
`internal_symbol()` and `release-split`'s own exclusion list treat as internal, so
the object's only API is the trigger - and that is the whole API of iOS 10.0 this
slice owns.