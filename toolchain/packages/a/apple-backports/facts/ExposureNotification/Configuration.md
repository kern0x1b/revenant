# `ENExposureConfiguration`, iOS 12.5

`Foundation/ENExposureConfiguration.m`: the twenty-four weights and thresholds an application sets and
`ENManager` reads when it is asked to detect exposures.

Every one of them is readwrite in Apple's own header, so every one of them here stores and returns what
the caller gave it. There is no initialiser to write beyond `NSObject`'s: the header declares none.

## What an application gets before it sets anything, and why it is the zero value

Apple's own object starts from the configuration Apple recommends. **No SDK header states those numbers.**
SDK 26.2's `ENCommon.h` declares the twenty-four properties and gives no default for any of them, and no
other header on this machine does either.

Nor is there anything on this release that could supply them. The service that reads this configuration is
`ENManager`, and `Manager.md` is why this release cannot detect an exposure: no framework, no
entitlement, and no Bluetooth Low Energy subsystem to broadcast over.

**These zeros are not Apple's values and are not claimed to be.** They are what this port answers before
a caller sets a weight, and they are a known gap, not a finding. A caller that sets all twenty-four never
sees them.

Which values Apple recommends is in the iOS 16.0 arm64e cache, and it has not been read out of it yet. The
image extracts cleanly with charon's own reader --

```
$ CHARON_ROOT=$PWD xmake l extract-image.lua ~/.charon/dyld/16.0/dyld_shared_cache_arm64e ExposureNotification out
/System/Library/Frameworks/ExposureNotification.framework/ExposureNotification: 209290691 bytes, 0 rebased pointers, 1684 symbols
```

-- and `out` is a real `Mach-O 64-bit dynamically linked shared library arm64e` that `xcrun otool` reads.
What is left is three steps, and none of them has been done: the class's `_OBJC_CLASS_$_` symbol is at
`0x213d52f00`, its `objc_class`'s `data` word is `0x5c040402cc03f009`, which is a DYLD_CHAINED_PTR_64 that
this path does not decode; from the class ro, `-init`'s IMP; and from the disassembly of it, the doubles
it stores, mapped to property names through the class's own ivar layout. A number put here before that is
read would be invented, and an invented weight silently changes every risk score computed from it.

## The twenty-four, as the header declares them

| property | type |
| --- | --- |
| immediateDurationWeight, nearDurationWeight, mediumDurationWeight, otherDurationWeight | double |
| infectiousnessForDaysSinceOnsetOfSymptoms | NSDictionary of NSNumber to NSNumber |
| infectiousnessStandardWeight, infectiousnessHighWeight | double |
| reportTypeConfirmedTestWeight, reportTypeConfirmedClinicalDiagnosisWeight, reportTypeSelfReportedWeight, reportTypeRecursiveWeight | double |
| reportTypeNoneMap | ENDiagnosisReportType |
| attenuationDurationThresholds, attenuationLevelValues, daysSinceLastExposureLevelValues, durationLevelValues, transmissionRiskLevelValues | NSArray of NSNumber |
| daysSinceLastExposureThreshold | NSInteger |
| minimumRiskScoreFullRange, attenuationWeight, daysSinceLastExposureWeight, durationWeight, transmissionRiskWeight, minimumRiskScore | double (the last is ENRiskScore) |
| metadata | NSDictionary |
