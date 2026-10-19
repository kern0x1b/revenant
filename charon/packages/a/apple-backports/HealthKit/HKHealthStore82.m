#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKHealthStore (CharonIOS82)

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
