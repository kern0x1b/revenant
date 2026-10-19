// The 20 exported string constants the held ladder first sees exported by iOS 13.4: the audio exposure,
// heart rate event and heartbeat series names, the predicate key paths of the most-recent and aggregate
// queries, and the stand time and audio exposure quantities. The other 125 of the framework's constants
// the ladder places at iOS 16.0 are in HKConstants160.m. Each object carries the API of one release.
//
// The values are Apple's own, read out of the host's HealthKit as the constants of HKConstants160.m are,
// and recorded per constant in coordination/corpus/ledger/constant-values-HealthKit.tsv. The release is
// the one tools/release-split.lua measures on the held ladder; the registry rows keep the release each
// header names, and facts/HealthKit/HealthKit.md writes down where the two differ.
#import <HealthKit/HealthKit.h>

HKCategoryTypeIdentifier const HKCategoryTypeIdentifierAudioExposureEvent = @"HKCategoryTypeIdentifierAudioExposureEvent";
HKCategoryTypeIdentifier const HKCategoryTypeIdentifierHighHeartRateEvent = @"HKCategoryTypeIdentifierHighHeartRateEvent";
HKCategoryTypeIdentifier const HKCategoryTypeIdentifierIrregularHeartRhythmEvent = @"HKCategoryTypeIdentifierIrregularHeartRhythmEvent";
HKCategoryTypeIdentifier const HKCategoryTypeIdentifierLowHeartRateEvent = @"HKCategoryTypeIdentifierLowHeartRateEvent";
HKCategoryTypeIdentifier const HKCategoryTypeIdentifierToothbrushingEvent = @"HKCategoryTypeIdentifierToothbrushingEvent";
NSString * const HKDataTypeIdentifierHeartbeatSeries = @"HKDataTypeIdentifierHeartbeatSeries";
NSString * const HKMetadataKeyAudioExposureLevel = @"HKMetadataKeyAudioExposureLevel";
NSString * const HKMetadataKeyAverageMETs = @"HKAverageMETs";
NSString * const HKMetadataKeyHeartRateEventThreshold = @"HKHeartRateEventThreshold";
NSString * const HKPredicateKeyPathAverage = @"quantity";
NSString * const HKPredicateKeyPathCount = @"count";
NSString * const HKPredicateKeyPathMax = @"max";
NSString * const HKPredicateKeyPathMin = @"min";
NSString * const HKPredicateKeyPathMostRecent = @"most_recent";
NSString * const HKPredicateKeyPathMostRecentDuration = @"most_recent_duration";
NSString * const HKPredicateKeyPathMostRecentEndDate = @"most_recent_end_date";
NSString * const HKPredicateKeyPathMostRecentStartDate = @"most_recent_start_date";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierAppleStandTime = @"HKQuantityTypeIdentifierAppleStandTime";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierEnvironmentalAudioExposure = @"HKQuantityTypeIdentifierEnvironmentalAudioExposure";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierHeadphoneAudioExposure = @"HKQuantityTypeIdentifierHeadphoneAudioExposure";
