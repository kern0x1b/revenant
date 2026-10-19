// The single exported string constant of iOS 26.2 this library carries: HKCategoryTypeIdentifierHypertensionEvent.
//
// One object for one constant, because an object carries the API of one release and this one carries one
// constant. It is placed by the registry: `dyld.first_releases()` over the held ladder answers "no rung
// exports it" - the ladder's last rung is 18.0 - and no header of the 16.4 build SDK declares it, so the
// 26.2 of ios262.json is what releases_in() has. The 26.2 header declares it with API_AVAILABLE(ios(26.2))
// (HKTypeIdentifiers.h), which is the date the row carries.
//
// Its value is its own name, and it is Apple's own: dlsym out of
// /System/Library/Frameworks/HealthKit.framework/HealthKit on macOS 26A428, recorded per constant in
// coordination/corpus/ledger/constant-values-HealthKit.tsv with that binary and that build on the row.

#import <HealthKit/HealthKit.h>

HKCategoryTypeIdentifier const HKCategoryTypeIdentifierHypertensionEvent = @"HKCategoryTypeIdentifierHypertensionEvent";
