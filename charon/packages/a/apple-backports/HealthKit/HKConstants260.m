// The seven exported string constants of iOS 26.0 this library carries, the half of that release's set that
// no held release of this workspace exports.
//
// The other two constants of 26.0 this library carries - HKMedicationDoseEventTypeIdentifierMedicationDoseEvent
// and HKPredicateKeyPathStatus - are in HKConstants160.m, and the reason is a measurement rather than a
// choice: `dyld.first_releases()` over the held ladder answers 16.0 for those two and "no rung exports it" for
// these seven, so one object of the two would hold two releases and the release check refuses it. The ladder's
// last rung is 18.0, which is why no 26.0 constant can be placed by an image at all and the registry places
// them: these seven take the 26.0 of ios260.json.
//
// Six of the seven hold a value that is not their own name, and two of those are key paths a predicate is
// built over rather than names: HKPredicateKeyPathScheduledDate is `scheduledDate` and
// HKPredicateKeyPathLogOrigin is `logOrigin`, beside medicationConceptIdentifier, hasSchedule and
// isArchived. HKDataTypeIdentifierUserAnnotatedMedicationConcept is `HKDataTypeUserAnnotatedMedicationConcept`
// - the `Identifier` is not in the string. Every value is Apple's own, dlsym'd out of
// /System/Library/Frameworks/HealthKit.framework/HealthKit on macOS 26A428 and recorded per constant in
// coordination/corpus/ledger/constant-values-HealthKit.tsv, with that binary and that build on every row. The
// 26.2 header declares all seven with API_AVAILABLE(ios(26.0)) and the corpus ledger's `introduced` agrees
// with that annotation for all seven.
//
// HKHealthConceptDomainMedication is spelled `NSString * const` rather than with its own typedef, because
// `typedef NSString * HKHealthConceptDomain NS_TYPED_ENUM API_AVAILABLE(ios(26.0), ...)`
// (HKHealthConceptIdentifier.h:20 of 26.2) is a declaration the 16.4 build SDK does not carry and the type it
// expands to is `NSString *`.

#import <HealthKit/HealthKit.h>

NSString * const HKDataTypeIdentifierUserAnnotatedMedicationConcept = @"HKDataTypeUserAnnotatedMedicationConcept";
NSString * const HKHealthConceptDomainMedication = @"HKHealthConceptDomainMedication";
NSString * const HKPredicateKeyPathLogOrigin = @"logOrigin";
NSString * const HKPredicateKeyPathMedicationConceptIdentifier = @"medicationConceptIdentifier";
NSString * const HKPredicateKeyPathScheduledDate = @"scheduledDate";
NSString * const HKUserAnnotatedMedicationPredicateKeyPathHasSchedule = @"hasSchedule";
NSString * const HKUserAnnotatedMedicationPredicateKeyPathIsArchived = @"isArchived";
