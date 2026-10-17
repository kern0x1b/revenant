// The 33 exported string constants the held ladder first sees exported by iOS 18.0.
//
// They arrive in three releases by their own headers - 16.4 (4), 17.0 (12) and 18.0 (17) - and they are one
// object because an object carries the API of one release, measured the way the release check measures it:
// `dyld.first_releases()` over the held ladder answers 18.0 for all 33. The ladder's rungs are 12.0, 16.0 and
// then 18.0, so the 16.0 image - the rung before - predates every one of these constants and the 18.0 image
// exports them all; the same answer comes from `tools/symbol-first-release.lua` and from
// `tools/cache-index/first-rung.lua` over the same ladder. Their rows keep the release each header names, so
// ios164.json says 16.4 for the four that arrived in 16.4 and ios170.json says 17.0 for the twelve of 17.0.
//
// Seven of the 33 hold a value that is not their own name - HKFHIRResourceTypeDiagnosticReport is
// `DiagnosticReport`, HKMetadataKeyActivityType is `HKActivityType`, HKPredicateKeyPathWorkoutEffortRelationship
// is `ratingOfExertionAssociation` and four more are of that shape - so a value spelled from the constant's
// name would be wrong for them. Every value is Apple's own, dlsym'd out of
// /System/Library/Frameworks/HealthKit.framework/HealthKit
// on macOS 26A428 and recorded per constant in coordination/corpus/ledger/constant-values-HealthKit.tsv,
// with that binary and that build on every row. All 33 are declared by the 26.2 header and the corpus
// ledger's `introduced` agrees with the header's own availability for all 33.
//
// The C type each definition carries is the typedef the 16.4 build SDK declares for it, and every typedef
// this file's constants use is one that SDK declares.

#import <HealthKit/HealthKit.h>

HKCategoryTypeIdentifier const HKCategoryTypeIdentifierBleedingAfterPregnancy = @"HKCategoryTypeIdentifierBleedingAfterPregnancy";
HKCategoryTypeIdentifier const HKCategoryTypeIdentifierBleedingDuringPregnancy = @"HKCategoryTypeIdentifierBleedingDuringPregnancy";
HKCategoryTypeIdentifier const HKCategoryTypeIdentifierSleepApneaEvent = @"HKCategoryTypeIdentifierSleepApneaEvent";
HKClinicalTypeIdentifier const HKClinicalTypeIdentifierClinicalNoteRecord = @"HKClinicalTypeIdentifierClinicalNoteRecord";
NSString * const HKDataTypeIdentifierStateOfMind = @"HKDataTypeStateOfMind";
HKFHIRResourceType const HKFHIRResourceTypeDiagnosticReport = @"DiagnosticReport";
HKFHIRResourceType const HKFHIRResourceTypeDocumentReference = @"DocumentReference";
NSString * const HKMetadataKeyActivityType = @"HKActivityType";
NSString * const HKMetadataKeyAppleFitnessPlusSession = @"HKMetadataKeyAppleFitnessPlusSession";
NSString * const HKMetadataKeyCyclingFunctionalThresholdPowerTestType = @"HKCyclingCyclingFunctionalThresholdPowerTestType";
NSString * const HKMetadataKeyHeadphoneGain = @"HKMetadataKeyHeadphoneGain";
NSString * const HKMetadataKeyMaximumLightIntensity = @"HKMetadataKeyMaximumLightIntensity";
NSString * const HKMetadataKeyPhysicalEffortEstimationType = @"HKPhysicalEffortEstimationType";
NSString * const HKMetadataKeyWaterSalinity = @"HKMetadataKeyWaterSalinity";
NSString * const HKPredicateKeyPathWorkoutEffortRelationship = @"ratingOfExertionAssociation";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances = @"HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierCrossCountrySkiingSpeed = @"HKQuantityTypeIdentifierCrossCountrySkiingSpeed";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierCyclingCadence = @"HKQuantityTypeIdentifierCyclingCadence";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierCyclingFunctionalThresholdPower = @"HKQuantityTypeIdentifierCyclingFunctionalThresholdPower";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierCyclingPower = @"HKQuantityTypeIdentifierCyclingPower";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierCyclingSpeed = @"HKQuantityTypeIdentifierCyclingSpeed";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistanceCrossCountrySkiing = @"HKQuantityTypeIdentifierDistanceCrossCountrySkiing";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistancePaddleSports = @"HKQuantityTypeIdentifierDistancePaddleSports";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistanceRowing = @"HKQuantityTypeIdentifierDistanceRowing";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistanceSkatingSports = @"HKQuantityTypeIdentifierDistanceSkatingSports";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierEstimatedWorkoutEffortScore = @"HKQuantityTypeIdentifierEstimatedWorkoutEffortScore";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierPaddleSportsSpeed = @"HKQuantityTypeIdentifierPaddleSportsSpeed";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierPhysicalEffort = @"HKQuantityTypeIdentifierPhysicalEffort";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierRowingSpeed = @"HKQuantityTypeIdentifierRowingSpeed";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierTimeInDaylight = @"HKQuantityTypeIdentifierTimeInDaylight";
HKQuantityTypeIdentifier const HKQuantityTypeIdentifierWorkoutEffortScore = @"HKQuantityTypeIdentifierWorkoutEffortScore";
NSString * const HKScoredAssessmentTypeIdentifierGAD7 = @"HKScoredAssessmentTypeIdentifierGAD7";
NSString * const HKScoredAssessmentTypeIdentifierPHQ9 = @"HKScoredAssessmentTypeIdentifierPHQ9";
