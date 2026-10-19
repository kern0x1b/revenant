#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKObject

@implementation HKObject (CharonIOS9)

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
