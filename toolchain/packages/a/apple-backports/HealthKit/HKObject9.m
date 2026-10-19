#import <HealthKit/HealthKit.h>

#import "RevenantHKStore.h"

#pragma mark - HKObject

@implementation HKObject (RevenantIOS9)

- (HKSourceRevision *)sourceRevision
{
    HKSourceRevision *stored = [self revenant_storedSourceRevision];
    if (stored)
        return stored;
    return [[HKSourceRevision alloc] revenant_initWithSource:self.source ?: [HKSource defaultSource]
                                                    version:[HKSource revenant_processVersion]];
}

- (nullable HKDevice *)device
{
    return [self revenant_storedDevice];
}

- (void)revenant_setSourceRevision:(nullable HKSourceRevision *)revision device:(nullable HKDevice *)device
{
    [self revenant_setStoredSourceRevision:revision];
    if (device)
        [self revenant_setDevice:device];
}

@end

#pragma mark - HKUnit

@implementation HKUnit (RevenantIOS9)

+ (instancetype)yardUnit
{
    return [self revenant_namedUnit:@"yd"];
}

+ (instancetype)cupUSUnit
{
    return [self revenant_namedUnit:@"cup_us"];
}

+ (instancetype)cupImperialUnit
{
    return [self revenant_namedUnit:@"cup_imp"];
}

@end

#pragma mark - The sample factories that take a device

@implementation HKCategorySample (RevenantIOS9)

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
    [sample revenant_setDevice:device];
    return sample;
}

@end

@implementation HKQuantitySample (RevenantIOS9)

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
    [sample revenant_setDevice:device];
    return sample;
}

@end

@implementation HKCorrelation (RevenantIOS9)

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
    [correlation revenant_setDevice:device];
    return correlation;
}

@end

@implementation HKWorkout (RevenantIOS9)

+ (instancetype)workoutWithActivityType:(HKWorkoutActivityType)activityType
                              startDate:(NSDate *)startDate
                                endDate:(NSDate *)endDate
                               duration:(NSTimeInterval)duration
                        totalEnergyBurned:(nullable HKQuantity *)totalEnergyBurned
                          totalDistance:(nullable HKQuantity *)totalDistance
                                 device:(nullable HKDevice *)device
                               metadata:(nullable NSDictionary *)metadata
{
    HKWorkout *workout = [[HKWorkout alloc] revenant_initWithType:[HKObjectType workoutType]
                                                           metadata:metadata
                                                          startDate:startDate
                                                            endDate:[startDate dateByAddingTimeInterval:duration]
                                                           duration:duration];
    if (workout) {
        [workout revenant_setDevice:device];
        [workout revenant_setWorkoutActivityType:activityType];
        [workout revenant_setTotalEnergyBurned:totalEnergyBurned totalDistance:totalDistance];
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
    [workout revenant_setDevice:device];
    return workout;
}

@end

#pragma mark - HKQuery

@implementation HKQuery (RevenantIOS9)

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
