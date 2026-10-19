// The iOS 10.0 members of HKHealthStore.
//
// Each is the same shape as the member of 8.0 it replaces, over the same store, so the two are read
// together: -dateOfBirthComponentsWithError: is what -dateOfBirthWithError: became when a date became
// a set of components in a calendar, and -wheelchairUseWithError: is the fourth characteristic the
// store keeps. -startWatchAppWithWorkoutConfiguration:completion: is the one wall in the group: it
// starts a workout on a paired watch, and this release has neither a watch application nor the daemon
// that would start one, so the call is refused with the release's own no-data error and the log says
// once why, rather than answering a success that started nothing.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

@implementation HKHealthStore (CharonIOS100)

// The user's date of birth, as the components of the Gregorian calendar, which is what 10.0 made this
// return and what -dateOfBirthWithError: of 8.0 became.
- (nullable NSDateComponents *)dateOfBirthComponentsWithError:(NSError *__autoreleasing *)error
{
    NSDate *date = [self dateOfBirthWithError:error];
    if (!date)
        return nil;
    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    return [[NSCalendar currentCalendar] components:units fromDate:date];
}

// The user's wheelchair use, the fourth characteristic the store keeps, read and refused in the same
// shape as the other three.
- (nullable HKWheelchairUseObject *)wheelchairUseWithError:(NSError *__autoreleasing *)error
{
    HKCharacteristicType *type = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierWheelchairUse];
    if (![[CharonHKStore sharedStore] mayReadType:type]) {
        if (error)
            *error = CharonHKError(HKErrorAuthorizationDenied, @"Reading the wheelchair use has not been authorized.", nil);
        return nil;
    }
    NSNumber *stored = [[CharonHKStore sharedStore] characteristicForIdentifier:HKCharacteristicTypeIdentifierWheelchairUse];
    if (!stored) {
        if (error)
            *error = CharonHKError(HKErrorHealthDataUnavailable,
                                   @"No wheelchair use is recorded. The user enters it in the Health application on a release "
                                   @"that has one.",
                                   nil);
        return nil;
    }
    return [HKWheelchairUseObject charon_wheelchairUseObject:(HKWheelchairUse)stored.integerValue];
}

// Starting a workout on the paired watch. The header gives this to iOS and not to watchOS, so it is
// iOS API: the call goes out to a watch application on the other wrist, and this release has no watch
// application and no daemon that would start one. It is refused with the release's own no-data error
// and the log says once why; a success here would be a success that started nothing.
- (void)startWatchAppWithWorkoutConfiguration:(HKWorkoutConfiguration *)workoutConfiguration
                                  completion:(void (^)(BOOL success, NSError *_Nullable error))completion
{
    if (!completion)
        return;
    charon_hk_say_once(@"start-watch-app",
                       @"HealthKit: -startWatchAppWithWorkoutConfiguration:completion: is refused. It starts a workout on the paired "
                       @"watch, and this release has no watch application and no daemon that would start one, so there is nothing to "
                       @"start.");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(NO, CharonHKError(HKErrorHealthDataUnavailable,
                                      @"There is no paired watch to start a workout on: this release has no watch application and no "
                                      @"daemon that would start one.",
                                      nil));
    });
}

@end
