# The `-init` and `+new` rows of HomeKit whose class carries neither selector

Twenty-four rows of `registry/HomeKit/model.json` name a `-init` or a `+new` of a class whose own method
lists carry neither selector in iOS 16.0. They stood at `absent`, whose meaning is "respondsToSelector:
answers NO". That is wrong for every one of them: a caller that reaches the selector gets NSObject's, and
`respondsToSelector:` answers YES on the release's own class and on this port's. The rows are `implemented`
now, and this file is what they rest on.

## The measurement

Read with `tools/objc-init-members.lua`, which goes through `apple.objc` and `apple.dyld` and never reads the
held caches directly. Its control is NSObject, which must show both selectors; a class that shows neither is
a real answer only when the control shows both.

```
$ xmake l tools/objc-init-members.lua 16.0 arm64e HMHome HMAction HMZone HMUser HMEvent HMTrigger HMEventTrigger \
      HMAccessoryProfile HMCameraProfile HMNumberRange HMAccessorySetupPayload HMAccessorySetupResult \
      HMAccessoryBrowser HMAccessoryOwnershipToken HMNetworkConfigurationProfile HMAccessorySetupManager \
      HMHomeAccessControl HMCharacteristicWriteAction HMHomeManager HMRoom HMServiceGroup HMTimerTrigger \
      HMAccessControl HMActionSet HMCalendarEvent HMPresenceEvent HMDurationEvent
source $HOME/.charon/dyld/16.0/dyld_shared_cache_arm64e
NSObject                                     super=nil                          -init=yes +init=yes +new=yes
HMHome                                       super=NSObject                     -init=yes +init=no  +new=no
HMAction                                     super=NSObject                     -init=yes +init=no  +new=no
HMZone                                       super=NSObject                     -init=yes +init=no  +new=no
HMUser                                       super=NSObject                     -init=yes +init=no  +new=no
HMEvent                                      super=NSObject                     -init=no  +init=no  +new=no
HMTrigger                                    super=NSObject                     -init=no  +init=no  +new=no
HMEventTrigger                               super=HMTrigger                    -init=no  +init=no  +new=no
HMAccessoryProfile                           super=NSObject                     -init=no  +init=no  +new=no
HMCameraProfile                              super=HMAccessoryProfile           -init=no  +init=no  +new=no
HMNumberRange                                super=NSObject                     -init=no  +init=no  +new=no
HMAccessorySetupPayload                      super=NSObject                     -init=no  +init=no  +new=no
HMAccessorySetupResult                       super=NSObject                     -init=no  +init=no  +new=no
HMAccessoryBrowser                           super=NSObject                     -init=yes +init=no  +new=no
HMAccessoryOwnershipToken                    super=NSObject                     -init=no  +init=no  +new=no
HMNetworkConfigurationProfile                super=HMAccessoryProfile           -init=no  +init=no  +new=no
HMAccessorySetupManager                      super=NSObject                     -init=yes +init=no  +new=no
HMHomeAccessControl                          super=HMAccessControl              -init=no  +init=no  +new=no
HMCharacteristicWriteAction                  super=HMAction                     -init=no  +init=no  +new=no
HMHomeManager                                super=NSObject                     -init=yes +init=no  +new=no
HMRoom                                       super=NSObject                     -init=yes +init=no  +new=no
HMServiceGroup                               super=NSObject                     -init=yes +init=no  +new=no
HMTimerTrigger                               super=HMTrigger                    -init=yes +init=no  +new=no
HMAccessControl                              super=NSObject                     -init=yes +init=no  +new=no
HMActionSet                                  super=NSObject                     -init=yes +init=no  +new=no
HMCalendarEvent                              super=HMTimeEvent                  -init=no  +init=no  +new=no
HMPresenceEvent                              super=HMEvent                      -init=no  +init=no  +new=no
HMDurationEvent                              super=HMTimeEvent                  -init=no  +init=no  +new=no
```

The second run took the remaining event classes the same way, with the same control:

```
HMCharacteristicThresholdRangeEvent          super=HMEvent                      -init=no  +init=no  +new=no
HMMutableCalendarEvent                       super=HMCalendarEvent              -init=no  +init=no  +new=no
HMMutableCharacteristicEvent                 super=HMCharacteristicEvent        -init=no  +init=no  +new=no
HMMutableCharacteristicThresholdRangeEvent   super=HMCharacteristicThresholdRangeEvent -init=no  +init=no  +new=no
HMMutableDurationEvent                       super=HMDurationEvent              -init=no  +init=no  +new=no
HMMutablePresenceEvent                       super=HMPresenceEvent              -init=no  +init=no  +new=no
HMSignificantTimeEvent                       super=HMTimeEvent                  -init=no  +init=no  +new=no
HMCharacteristicEvent                        super=HMEvent                      -init=no  +init=no  +new=no
HMLocationEvent                              super=HMEvent                      -init=no  +init=no  +new=no
HMTimeEvent                                  super=HMEvent                      -init=no  +init=no  +new=no
```

So the twenty classes the HomeKit rows name carry neither selector in their own lists. The classes that do define
`-init` (HMHome, HMAction, HMZone, HMUser, HMHomeManager, HMRoom, HMServiceGroup, HMTimerTrigger,
HMAccessControl, HMActionSet, HMAccessoryBrowser, HMAccessorySetupManager) are not in these rows; their
rows are decided elsewhere.

## The HealthKit rows this group closes, and the ones it does not

The same reader, over the same cache, for the HealthKit classes the rows name (the rows of `HealthKit/ios8.json`
and `HealthKit/ios90.json` and `HealthKit/ios120.json` that these facts also name):

```
$ xmake l tools/objc-init-members.lua 16.0 arm64e HKCategorySample HKObject HKObjectType HKQuantity HKSource \
      HKStatistics HKStatisticsCollection HKWorkoutEvent HKDeletedObject HKClinicalRecord HKFHIRResource
NSObject                                     super=nil                          -init=yes +init=yes +new=yes
HKCategorySample                             super=HKSample                     -init=yes +init=no  +new=no
HKObject                                     super=NSObject                     -init=yes +init=no  +new=no
HKObjectType                                 super=NSObject                     -init=yes +init=no  +new=no
HKQuantity                                   super=NSObject                     -init=yes +init=no  +new=no
HKSource                                     super=NSObject                     -init=yes +init=no  +new=no
HKStatistics                                 super=NSObject                     -init=yes +init=no  +new=no
HKStatisticsCollection                       super=NSObject                     -init=yes +init=no  +new=no
HKWorkoutEvent                               super=NSObject                     -init=yes +init=no  +new=no
HKDeletedObject                              super=NSObject                     -init=no  +init=no  +new=no
HKClinicalRecord                             super=HKSample                     -init=yes +init=no  +new=no
HKFHIRResource                               super=NSObject                     -init=yes +init=no  +new=no
```

So on 16.0 eight of the eight `-init` rows of `HealthKit/ios8.json` name a class that DOES define `-init`,
and `HKDeletedObject` is the one that does not. The earlier HealthKit facts, which said the eight carry no
`-init` of their own, were measured on an older release and do not describe 16.0. The eight are measured at run
time instead, on the macOS host (`tests/backports/host/init-inherited/host.sh`): each raises
`NSInvalidArgumentException` with the reason `The -init method is not available on <class>` from `-init` and from
`+new`, and the port's class answers the same. They are `implemented` with `CHARON_HEALTHKIT_UNCREATABLE_INIT`, and
`facts/HealthKit/HealthKit8Absent.md` section 4 holds the output. `HKDeletedObject` and the `+new` of `HKClinicalRecord` are
closed here as well: the first inherits NSObject's pair on 16.0, and the second reaches the `-init` the port raises
through NSObject's `+new`.

## What the port does, and what the check holds it to

The port defines neither selector on any of the twenty HomeKit classes, nor on HKDeletedObject. `tests/backports/host/init-inherited/check.lua`
scans every `@implementation` block of those classes in `HomeKit/*.m` and asserts that none defines `-init` or
`+new`; the control is `HMAction`, which does define one, so a scanner that reads nothing is caught. The same
check holds each row to `implemented` in the registry. The eight HealthKit rows are held the same way, and the source
checks for them are the macro in each block and no construction through `-init` or `+new`. The run is 67 checks, 0
failures. Two faults planted for this commit turned it red and were then reverted: a `[[HKStatistics alloc] init]` in
`HKStatistics.m`, and a removed macro in `HKQuantity.m`.

Reasoned, not measured: an `HMEvent` made with `alloc` and `init` is an NSObject object whose identifier is
whatever the framework assigns, which is none, because nothing assigns one through `-init`. That reading is
why an earlier port `-init` that invented a UUID was removed; the registry row's `effect` says the same.

## What is not measured here

- The built library's own class list. The gate's objects carry the same classes, and this check reads the
  source, not the object; the object is read with `apple.objc.binary_inventory` when a gate run is kept.
- Behaviour on a device. Nothing in HomeKit runs on a macOS host (no framework, and the SDK marks the
  types unavailable there), so the NSObject answer is measured on the cache and not run.
