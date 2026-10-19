#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

@implementation HKHealthStore (RevenantIOS100)

- (nullable NSDateComponents *)dateOfBirthComponentsWithError:(NSError *__autoreleasing *)error
{
    NSDate *date = [self dateOfBirthWithError:error];
    if (!date)
        return nil;
    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    return [[NSCalendar currentCalendar] components:units fromDate:date];
}

- (nullable HKWheelchairUseObject *)wheelchairUseWithError:(NSError *__autoreleasing *)error
{
    HKCharacteristicType *type = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierWheelchairUse];
    if (![[RevenantHKStore sharedStore] mayReadType:type]) {
        if (error)
            *error = RevenantHKError(HKErrorAuthorizationDenied, @"Reading the wheelchair use has not been authorized.", nil);
        return nil;
    }
    NSNumber *stored = [[RevenantHKStore sharedStore] characteristicForIdentifier:HKCharacteristicTypeIdentifierWheelchairUse];
    if (!stored) {
        if (error)
            *error = RevenantHKError(HKErrorHealthDataUnavailable,
                                   @"No wheelchair use is recorded. The user enters it in the Health application on a release "
                                   @"that has one.",
                                   nil);
        return nil;
    }
    return [HKWheelchairUseObject revenant_wheelchairUseObject:(HKWheelchairUse)stored.integerValue];
}

- (void)startWatchAppWithWorkoutConfiguration:(HKWorkoutConfiguration *)workoutConfiguration
                                  completion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (!completion)
        return;
    revenant_hk_say_once(@"start-watch-app",
                       @"HealthKit: -startWatchAppWithWorkoutConfiguration:completion: is refused. It starts a workout on the paired "
                       @"watch, and this release has no watch application and no daemon that would start one, so there is nothing to "
                       @"start.");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(NO, RevenantHKError(HKErrorHealthDataUnavailable,
                                      @"There is no paired watch to start a workout on: this release has no watch application and no "
                                      @"daemon that would start one.",
                                      nil));
    });
}

@end
