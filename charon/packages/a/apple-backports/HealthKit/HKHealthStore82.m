// The one member iOS 8.2 added to HKHealthStore, and the one constant of that release, in the
// category the SDK's own availability puts them in and so in a file of their own.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKHealthStore (CharonIOS82)

// The unit a quantity type is counted in, for each type asked about, out of the SDK's own table of the
// type's unit. A type that table counts in a string no unit can be made of is left out, which is the
// same refusal +[HKQuantityType canonicalUnitForQuantityType:] of the next release makes and for the
// same reason: the SDK names a string for it and no source this port can read names a unit.
- (void)preferredUnitsForQuantityTypes:(NSSet<HKQuantityType *> *)quantityTypes
                           completion:(void (^)(NSDictionary<HKQuantityType *, HKUnit *> *_Nullable preferredUnits,
                                                NSError *_Nullable error))completion
{
    if (!completion)
        return;
    NSMutableDictionary<HKQuantityType *, HKUnit *> *units = [NSMutableDictionary dictionary];
    for (HKQuantityType *type in quantityTypes) {
        HKUnit *unit = [HKUnit charon_canonicalUnitForType:type];
        if (unit)
            units[type] = unit;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(units, nil);
    });
}

@end
