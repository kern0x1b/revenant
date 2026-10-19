#import <HealthKit/HealthKit.h>

#import "CharonHKStore.h"

#pragma mark - HKActivitySummary

@implementation HKActivitySummary {
    HKQuantity *_activeEnergyBurned;
    HKQuantity *_activeEnergyBurnedGoal;
    HKQuantity *_appleExerciseTime;
    HKQuantity *_appleExerciseTimeGoal;
    HKQuantity *_appleStandHours;
    HKQuantity *_appleStandHoursGoal;
    NSDate *_startDate;
    NSDateComponents *_dateComponents;
}

@dynamic activityMoveMode;
@dynamic appleMoveTime;
@dynamic appleMoveTimeGoal;
@dynamic exerciseTimeGoal;
@dynamic standHoursGoal;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)charon_initWithStartDate:(NSDate *)startDate
{
    HKActivitySummary *summary = [super init];
    if (summary) {
        summary->_startDate = [startDate copy];
        summary->_dateComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth |
                                                                           NSCalendarUnitDay
                                                               fromDate:startDate];
        summary->_activeEnergyBurned = [HKQuantity quantityWithUnit:[HKUnit kilocalorieUnit] doubleValue:0.0];
        summary->_activeEnergyBurnedGoal = [HKQuantity quantityWithUnit:[HKUnit kilocalorieUnit] doubleValue:0.0];
        summary->_appleExerciseTime = [HKQuantity quantityWithUnit:[HKUnit minuteUnit] doubleValue:0.0];
        summary->_appleExerciseTimeGoal = [HKQuantity quantityWithUnit:[HKUnit minuteUnit] doubleValue:0.0];
        summary->_appleStandHours = [HKQuantity quantityWithUnit:[HKUnit hourUnit] doubleValue:0.0];
        summary->_appleStandHoursGoal = [HKQuantity quantityWithUnit:[HKUnit hourUnit] doubleValue:0.0];
    }
    return summary;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    HKActivitySummary *summary = [super init];
    if (summary) {
        summary->_startDate = [[coder decodeObjectOfClass:[NSDate class] forKey:@"startDate"] copy];
        summary->_dateComponents = [[coder decodeObjectOfClass:[NSDateComponents class] forKey:@"dateComponents"] copy];
        summary->_activeEnergyBurned = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"activeEnergyBurned"] copy];
        summary->_activeEnergyBurnedGoal = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"activeEnergyBurnedGoal"] copy];
        summary->_appleExerciseTime = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"appleExerciseTime"] copy];
        summary->_appleExerciseTimeGoal = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"appleExerciseTimeGoal"] copy];
        summary->_appleStandHours = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"appleStandHours"] copy];
        summary->_appleStandHoursGoal = [[coder decodeObjectOfClass:[HKQuantity class] forKey:@"appleStandHoursGoal"] copy];
    }
    return summary;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_startDate forKey:@"startDate"];
    [coder encodeObject:_dateComponents forKey:@"dateComponents"];
    [coder encodeObject:_activeEnergyBurned forKey:@"activeEnergyBurned"];
    [coder encodeObject:_activeEnergyBurnedGoal forKey:@"activeEnergyBurnedGoal"];
    [coder encodeObject:_appleExerciseTime forKey:@"appleExerciseTime"];
    [coder encodeObject:_appleExerciseTimeGoal forKey:@"appleExerciseTimeGoal"];
    [coder encodeObject:_appleStandHours forKey:@"appleStandHours"];
    [coder encodeObject:_appleStandHoursGoal forKey:@"appleStandHoursGoal"];
}

- (id)copyWithZone:(NSZone *)zone
{
    HKActivitySummary *copy = [[HKActivitySummary alloc] charon_initWithStartDate:_startDate];
    copy->_dateComponents = [_dateComponents copy];
    copy->_activeEnergyBurned = [_activeEnergyBurned copy];
    copy->_activeEnergyBurnedGoal = [_activeEnergyBurnedGoal copy];
    copy->_appleExerciseTime = [_appleExerciseTime copy];
    copy->_appleExerciseTimeGoal = [_appleExerciseTimeGoal copy];
    copy->_appleStandHours = [_appleStandHours copy];
    copy->_appleStandHoursGoal = [_appleStandHoursGoal copy];
    return copy;
}

- (HKQuantity *)activeEnergyBurned
{
    return _activeEnergyBurned;
}

- (void)setActiveEnergyBurned:(HKQuantity *)activeEnergyBurned
{
    _activeEnergyBurned = [activeEnergyBurned copy];
}

- (HKQuantity *)activeEnergyBurnedGoal
{
    return _activeEnergyBurnedGoal;
}

- (void)setActiveEnergyBurnedGoal:(HKQuantity *)activeEnergyBurnedGoal
{
    _activeEnergyBurnedGoal = [activeEnergyBurnedGoal copy];
}

- (HKQuantity *)appleExerciseTime
{
    return _appleExerciseTime;
}

- (void)setAppleExerciseTime:(HKQuantity *)appleExerciseTime
{
    _appleExerciseTime = [appleExerciseTime copy];
}

- (HKQuantity *)appleExerciseTimeGoal
{
    return _appleExerciseTimeGoal;
}

- (void)setAppleExerciseTimeGoal:(HKQuantity *)appleExerciseTimeGoal
{
    _appleExerciseTimeGoal = [appleExerciseTimeGoal copy];
}

- (HKQuantity *)appleStandHours
{
    return _appleStandHours;
}

- (void)setAppleStandHours:(HKQuantity *)appleStandHours
{
    _appleStandHours = [appleStandHours copy];
}

- (HKQuantity *)appleStandHoursGoal
{
    return _appleStandHoursGoal;
}

- (void)setAppleStandHoursGoal:(HKQuantity *)appleStandHoursGoal
{
    _appleStandHoursGoal = [appleStandHoursGoal copy];
}

- (NSDateComponents *)dateComponents
{
    return _dateComponents;
}

- (NSDateComponents *)dateComponentsForCalendar:(NSCalendar *)calendar
{
    if (![calendar isKindOfClass:[NSCalendar class]])
        return nil;
    if (!_startDate)
        return nil;
    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    return [calendar components:units fromDate:_startDate];
}

+ (nullable instancetype)charon_objectFromArchive:(NSData *)archive type:(HKObjectType *)type store:(CharonHKStore *)store
{
    if (!archive.length || ![self supportsSecureCoding])
        return nil;
    NSKeyedUnarchiver *coder = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    HKActivitySummary *summary = [[self alloc] initWithCoder:coder];
    [coder finishDecoding];
    return summary;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"HKActivitySummary %@", _startDate];
}

@end

#pragma mark - HKActivitySummaryType

@implementation HKActivitySummaryType
@end
