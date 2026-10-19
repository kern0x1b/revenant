// The iOS 9.3 group: the activity ring.
//
// What a summary is, is a day's standing in three rings - the move ring, the exercise ring and the
// stand ring - with each ring's total and its goal, and a day it belongs to. The rings are counted by
// the phone itself and written by the Activity application of the release that has one; iOS 6.1.3 has
// no Activity application and no health store of Apple's, so the table this library keeps for them is
// empty and an activity summary query answers an empty array. That is said once in the log and in
// facts/HealthKit/HealthKit.md, and everything else here is real: the six properties, their units, the
// date components, the coding, the type, the two predicates and the query's own long-running form.
//
// One object per release, so each of these is a file of its own.

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

// The ring members of the releases after 9.3, which this delivery does not carry: @dynamic, so no
// accessor is emitted and the selector is not in the built library. They are 14.0's
// -activityMoveMode, -appleMoveTime and -appleMoveTimeGoal, 16.0's -exerciseTimeGoal and
// -standHoursGoal; the group of each release answers them there. 18.0's -paused is of a release
// later than the header this library is compiled against, so it is not declared there and nothing
// is synthesised for it.
@dynamic activityMoveMode;
@dynamic appleMoveTime;
@dynamic appleMoveTimeGoal;
@dynamic exerciseTimeGoal;
@dynamic standHoursGoal;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The store makes one of these for a day the device recorded; nothing else does, and iOS 9.3's public
// API of HKHealthStore has no way to save one - -saveObject:withCompletion: takes an HKObject, and a
// summary is not one.
// A summary is a day's standing, and what the store keeps of it is the day - the start of the day in
// the calendar the device counts rings in. The six ring totals begin at zero in the units the header
// names for them, so that a caller reading one before the day is filled in gets a number and not a nil,
// which is what the release answers for a ring the phone has not counted yet.
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

// The ring totals, in the units the header names for them: the move and exercise rings in kilocalories
// and minutes, and the stand ring in hours. The release holds each of them in its own unit and answers
// a value converted to the one the caller asks for, which -doubleValueForUnit: does for this library
// as well.
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

// The day the summary is for, in the calendar the device counts rings in. This is the path
// HKPredicateKeyPathDateComponents holds - "dateComponents", read out of iOS 9.0's own image - and the
// two predicates of HKQuery are built over it, so the property is here and not only the calendar
// conversion below. The release declares neither it nor the string the key path names in its public
// header, and both are its own: the key path is exported data and this is what it names.
- (NSDateComponents *)dateComponents
{
    return _dateComponents;
}

// The day the summary is for, as the given calendar writes it. What the store keeps is the day's
// start in the calendar the device counts rings in, and this converts it into the caller's own - a
// summary of the same day asked for through two calendars gives the two calendars' days of it, which
// is what the release does and what the method is for.
- (NSDateComponents *)dateComponentsForCalendar:(NSCalendar *)calendar
{
    if (![calendar isKindOfClass:[NSCalendar class]])
        return nil;
    if (!_startDate)
        return nil;
    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    return [calendar components:units fromDate:_startDate];
}

// A summary is an NSObject and not an HKObject, so it is not one of the store's own samples and does
// not inherit the reader those share. It reads itself back out of its own archive, which is its own
// NSSecureCoding - the same shape a sample is kept in, so that the store's one table holds both.
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
