// The iOS 9.0 members of the classes of iOS 8.0, each in the category the SDK itself puts it in, and
// so in a file of its own: one object carries the API of one release.
//
// What arrived in 9.0 is a device and a source revision on every object, the factories that take a
// device, three more predicates, the two units the 8.0 table lacked, and the anchored query's
// long-running form.

#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKObject

@implementation HKObject (CharonIOS9)

// The revision of the source that wrote this object. The header promises it nonnull, and it is: an
// object the store read back carries the revision it was written under, and one made in memory and not
// yet written carries the revision of the process that made it, which is the version of the
// application it is in. The header's own note says the release does the same after a save.
- (HKSourceRevision *)sourceRevision
{
    HKSourceRevision *stored = [self charon_storedSourceRevision];
    if (stored)
        return stored;
    return [[HKSourceRevision alloc] charon_initWithSource:self.source ?: [HKSource defaultSource]
                                                    version:[HKSource charon_processVersion]];
}

- (nullable HKDevice *)device
{
    return [self charon_storedDevice];
}

- (void)charon_setSourceRevision:(nullable HKSourceRevision *)revision device:(nullable HKDevice *)device
{
    [self charon_setStoredSourceRevision:revision];
    if (device)
        [self charon_setDevice:device];
}

@end

#pragma mark - HKUnit

// The three units iOS 8.0's table of the header's factories did not name, which the header adds in
// 9.0: the yard, and the US and imperial cup.
@implementation HKUnit (CharonIOS9)

+ (instancetype)yardUnit
{
    return [self charon_namedUnit:@"yd"];
}

+ (instancetype)cupUSUnit
{
    return [self charon_namedUnit:@"cup_us"];
}

+ (instancetype)cupImperialUnit
{
    return [self charon_namedUnit:@"cup_imp"];
}

@end

#pragma mark - The sample factories that take a device

@implementation HKCategorySample (CharonIOS9)

+ (instancetype)categorySampleWithType:(HKCategoryType *)type
                                 value:(NSInteger)value
                             startDate:(NSDate *)startDate
                               endDate:(NSDate *)endDate
                                device:(nullable HKDevice *)device
                              metadata:(nullable NSDictionary *)metadata
{
    HKCategorySample *sample = [self categorySampleWithType:type
                                                      value:value
                                                  startDate:startDate
                                                    endDate:endDate
                                                   metadata:metadata];
    [sample charon_setDevice:device];
    return sample;
}

@end

@implementation HKQuantitySample (CharonIOS9)

+ (instancetype)quantitySampleWithType:(HKQuantityType *)type
                             quantity:(HKQuantity *)quantity
                            startDate:(NSDate *)startDate
                              endDate:(NSDate *)endDate
                               device:(nullable HKDevice *)device
                             metadata:(nullable NSDictionary *)metadata
{
    HKQuantitySample *sample = [self quantitySampleWithType:type
                                                     quantity:quantity
                                                    startDate:startDate
                                                      endDate:endDate
                                                     metadata:metadata];
    [sample charon_setDevice:device];
    return sample;
}

@end

@implementation HKCorrelation (CharonIOS9)

+ (instancetype)correlationWithType:(HKCorrelationType *)type
                          startDate:(NSDate *)startDate
                            endDate:(NSDate *)endDate
                            objects:(NSSet<HKSample *> *)objects
                             device:(nullable HKDevice *)device
                           metadata:(nullable NSDictionary *)metadata
{
    HKCorrelation *correlation = [self correlationWithType:type
                                                 startDate:startDate
                                                   endDate:endDate
                                                   objects:objects
                                                  metadata:metadata];
    [correlation charon_setDevice:device];
    return correlation;
}

@end

@implementation HKWorkout (CharonIOS9)

+ (instancetype)workoutWithActivityType:(HKWorkoutActivityType)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                               duration:(NSTimeInterval)duration
                        totalEnergyBurned:(nullable HKQuantity *)totalEnergyBurned
                          totalDistance:(nullable HKQuantity *)totalDistance
                                 device:(nullable HKDevice *)device
                               metadata:(nullable NSDictionary *)metadata
{
    // The form with a device is the release's own form plus a device, so it keeps what the form
    // without one keeps: a duration given here is the duration the workout has, and it ends at the
    // start plus that duration. It goes through the constructor that stores the duration, not through
    // the two-dates one, so that -duration answers the number the caller passed.
    HKWorkout *workout = [[HKWorkout alloc] charon_initWithType:[HKObjectType workoutType]
                                                           metadata:metadata
                                                          startDate:startDate
                                                            endDate:[startDate dateByAddingTimeInterval:duration]
                                                           duration:duration];
    if (workout) {
        [workout charon_setDevice:device];
        [workout charon_setWorkoutActivityType:activityType];
        [workout charon_setTotalEnergyBurned:totalEnergyBurned totalDistance:totalDistance];
    }
    return workout;
}

+ (instancetype)workoutWithActivityType:(HKWorkoutActivityType)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                         workoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents
                    totalEnergyBurned:(nullable HKQuantity *)totalEnergyBurned
                      totalDistance:(nullable HKQuantity *)totalDistance
                               device:(nullable HKDevice *)device
                             metadata:(nullable NSDictionary *)metadata
{
    HKWorkout *workout = [self workoutWithActivityType:activityType
                                              startDate:startDate
                                                endDate:endDate
                                         workoutEvents:workoutEvents
                                    totalEnergyBurned:totalEnergyBurned
                                      totalDistance:totalDistance
                                               metadata:metadata];
    [workout charon_setDevice:device];
    return workout;
}

@end

#pragma mark - HKQuery

@implementation HKQuery (CharonIOS9)

// The three predicates that walk a device and a source revision, over the two key paths the 9.0 image
// of HealthKit holds: "device" and "sourceRevision", read out of that image's own string table.
+ (NSPredicate *)predicateForObjectsFromDevices:(NSSet<HKDevice *> *)devices
{
    if (!devices.count)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K IN %@", HKPredicateKeyPathDevice, devices];
}

+ (NSPredicate *)predicateForObjectsFromSourceRevisions:(NSSet<HKSourceRevision *> *)sourceRevisions
{
    if (!sourceRevisions.count)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K IN %@", HKPredicateKeyPathSourceRevision, sourceRevisions];
}

+ (NSPredicate *)predicateForObjectsWithDeviceProperty:(NSString *)key allowedValues:(NSSet *)allowedValues
{
    if (![key isKindOfClass:[NSString class]] || !key.length)
        return nil;
    return [NSPredicate predicateWithFormat:@"%K.%K IN %@", HKPredicateKeyPathDevice, key, allowedValues];
}

@end
