// The single exported string constant of 18.2 this library carries: HKMetadataKeyAppleFitnessPlusCatalogIdentifier.
//
// One object for one constant, because an object carries the API of one release and this one carries one
// constant. The release is measured, not read off a header: `dyld.first_releases()` over the held ladder
// answers "no rung exports it" - the ladder's last rung is 18.0 and this constant is of 18.2 - so
// releases_in() falls back to the registry, and the 18.2 of ios182.json is what places this object. The 26.2
// header declares it with API_AVAILABLE(ios(18.2)) (HKMetadata.h), which is the date the row carries.
//
// Its value is its own name, and it is Apple's own: dlsym out of
// /System/Library/Frameworks/HealthKit.framework/HealthKit on macOS 26A428, recorded per constant in
// coordination/corpus/ledger/constant-values-HealthKit.tsv with that binary and that build on the row.

#import <HealthKit/HealthKit.h>

NSString * const HKMetadataKeyAppleFitnessPlusCatalogIdentifier = @"HKMetadataKeyAppleFitnessPlusCatalogIdentifier";
