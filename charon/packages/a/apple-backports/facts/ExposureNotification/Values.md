# ExposureNotification's value classes, iOS 12.5 (and one property of 15.2)

`Foundation/ENExposureValues.m` carries seven of the framework's nine classes, and
`Foundation/ENExposureWindowVariant15.m` the one member that arrived later.

The seven: `ENTemporaryExposureKey`, `ENScanInstance`, `ENExposureSummaryItem`, `ENExposureDaySummary`,
`ENExposureWindow`, `ENExposureDetectionSummary`, `ENExposureInfo`. Every property of every one of them is
read back out of the archive the object was decoded from, over the release's own `NSKeyedArchiver` and
`NSKeyedUnarchiver`, and `+supportsSecureCoding` answers YES, which is the protocol each class adopts in
Apple's own header.

## Why they are reached by coding, and not by an initialiser

No SDK header declares a public initialiser for any of the seven. SDK 26.2's `ENCommon.h` gives each
class's properties and nothing else, because on a system that runs Exposure Notification these objects
only ever come out of the framework's own service. On this release there is no such service -- see
`Manager.md` -- so the classes here are reached the way a value type is reached when nothing produces it:
as `NSSecureCoding`.

The archive keys are the property names, which is the shape a keyed archive of an object with these
properties has. What one of these writes, another reads back with every property answering what it was
given. Nothing on this release produces Apple's own archive of these objects, so there is no second
archive to agree with; what would make it one is `ENManager` answering with real values, which needs the
service.

## `ENExposureWindow.variantOfConcernType`

Arrived in iOS 15.2, so it is a category in its own object and `ENExposureValues.m` is `@dynamic` for it:
the 12.5 object must export no symbol for a member of a later release. The value is an associated object
rather than an ivar, which is the one mechanism that gives a category storage -- a category may not
`synthesize` a property, and an ivar added to the 12.5 object's `@implementation` cannot be named from
another file at all. `ENVariantOfConcernType` is the framework's own enumeration and `ENCommon.h` gives
every case of it a number.

## The property types, as the header declares them

Read from SDK 26.2's `ENCommon.h`, which is where each type and each `readonly`/`readwrite` comes from:

| class | properties |
| --- | --- |
| `ENExposureSummaryItem` | scoreSum (double), maximumScore (double), weightedDurationSum (NSTimeInterval) |
| `ENScanInstance` | secondsSinceLastScan (NSInteger), minimumAttenuation (ENAttenuation), typicalAttenuation (ENAttenuation) |
| `ENExposureWindow` | date (NSDate), scanInstances (NSArray), diagnosisReportType, infectiousness, calibrationConfidence, variantOfConcernType |
| `ENExposureDaySummary` | date (NSDate), daySummary, confirmedTestSummary, confirmedClinicalDiagnosisSummary, recursiveSummary, selfReportedSummary |
| `ENExposureDetectionSummary` | daysSinceLastExposure (NSInteger), matchedKeyCount (uint64_t), maximumRiskScore, maximumRiskScoreFullRange, riskScoreSumFullRange, attenuationDurations, metadata, daySummaries |
| `ENExposureInfo` | date (NSDate), diagnosisReportType, daysSinceOnsetOfSymptoms, duration, totalRiskScore, totalRiskScoreFullRange, attenuationValue, transmissionRiskLevel, attenuationDurations, metadata |
| `ENTemporaryExposureKey` | keyData (NSData), rollingStartNumber, rollingPeriod, transmissionRiskLevel -- all four readwrite, as the header declares |

`ENTemporaryExposureKey`'s four are readwrite because a diagnosis key is data an application publishes,
and the header declares them readwrite. The rest are readonly in the header and readonly here.
