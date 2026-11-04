#include "../revenant_impl.h"
#import <HealthKit/HealthKit.h>

HKCategoryTypeIdentifier const BACKPORT_IMPL(HKCategoryTypeIdentifierAudioExposureEvent) = @"HKCategoryTypeIdentifierAudioExposureEvent";
HKCategoryTypeIdentifier const BACKPORT_IMPL(HKCategoryTypeIdentifierHighHeartRateEvent) = @"HKCategoryTypeIdentifierHighHeartRateEvent";
HKCategoryTypeIdentifier const BACKPORT_IMPL(HKCategoryTypeIdentifierIrregularHeartRhythmEvent) = @"HKCategoryTypeIdentifierIrregularHeartRhythmEvent";
HKCategoryTypeIdentifier const BACKPORT_IMPL(HKCategoryTypeIdentifierLowHeartRateEvent) = @"HKCategoryTypeIdentifierLowHeartRateEvent";
HKCategoryTypeIdentifier const BACKPORT_IMPL(HKCategoryTypeIdentifierToothbrushingEvent) = @"HKCategoryTypeIdentifierToothbrushingEvent";
NSString * const BACKPORT_IMPL(HKDataTypeIdentifierHeartbeatSeries) = @"HKDataTypeIdentifierHeartbeatSeries";
NSString * const BACKPORT_IMPL(HKMetadataKeyAudioExposureLevel) = @"HKMetadataKeyAudioExposureLevel";
NSString * const BACKPORT_IMPL(HKMetadataKeyAverageMETs) = @"HKAverageMETs";
NSString * const BACKPORT_IMPL(HKMetadataKeyHeartRateEventThreshold) = @"HKHeartRateEventThreshold";
NSString * const BACKPORT_IMPL(HKPredicateKeyPathAverage) = @"quantity";
NSString * const BACKPORT_IMPL(HKPredicateKeyPathCount) = @"count";
NSString * const BACKPORT_IMPL(HKPredicateKeyPathMax) = @"max";
NSString * const BACKPORT_IMPL(HKPredicateKeyPathMin) = @"min";
NSString * const BACKPORT_IMPL(HKPredicateKeyPathMostRecent) = @"most_recent";
NSString * const BACKPORT_IMPL(HKPredicateKeyPathMostRecentDuration) = @"most_recent_duration";
NSString * const BACKPORT_IMPL(HKPredicateKeyPathMostRecentEndDate) = @"most_recent_end_date";
NSString * const BACKPORT_IMPL(HKPredicateKeyPathMostRecentStartDate) = @"most_recent_start_date";
HKQuantityTypeIdentifier const BACKPORT_IMPL(HKQuantityTypeIdentifierAppleStandTime) = @"HKQuantityTypeIdentifierAppleStandTime";
HKQuantityTypeIdentifier const BACKPORT_IMPL(HKQuantityTypeIdentifierEnvironmentalAudioExposure) = @"HKQuantityTypeIdentifierEnvironmentalAudioExposure";
HKQuantityTypeIdentifier const BACKPORT_IMPL(HKQuantityTypeIdentifierHeadphoneAudioExposure) = @"HKQuantityTypeIdentifierHeadphoneAudioExposure";
