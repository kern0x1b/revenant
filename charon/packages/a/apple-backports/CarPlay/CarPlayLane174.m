#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlay174.h"
#import "CharonCarPlayLane.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CPLane {
    CPLaneStatus _status;
    NSMeasurement<NSUnitAngle *> *_primaryAngle;
    NSArray<NSMeasurement<NSUnitAngle *> *> *_secondaryAngles;
    NSMeasurement<NSUnitAngle *> *_charonHighlightedAngle;
    NSArray<NSMeasurement<NSUnitAngle *> *> *_charonAngles;
}

@dynamic highlightedAngle;
@dynamic angles;

@synthesize status = _status;
@synthesize primaryAngle = _primaryAngle;
@synthesize secondaryAngles = _secondaryAngles;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _status = CPLaneStatusNotGood;
    }
    return self;
}

- (void)setStatus:(CPLaneStatus)status
{
    _status = status;
}

- (NSArray<NSMeasurement<NSUnitAngle *> *> *)secondaryAngles
{
    return _secondaryAngles;
}

- (void)setSecondaryAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)secondaryAngles
{
    _secondaryAngles = [secondaryAngles copy];
}

- (NSMeasurement<NSUnitAngle *> *)primaryAngle
{
    return _primaryAngle;
}

- (void)setPrimaryAngle:(NSMeasurement<NSUnitAngle *> *)primaryAngle
{
    _primaryAngle = primaryAngle;
}

- (NSMeasurement<NSUnitAngle *> *)charon_highlightedAngle
{
    return _charonHighlightedAngle;
}

- (void)charon_setHighlightedAngle:(NSMeasurement<NSUnitAngle *> *)angle
{
    _charonHighlightedAngle = angle;
}

- (NSArray<NSMeasurement<NSUnitAngle *> *> *)charon_angles
{
    return _charonAngles;
}

- (void)charon_setAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    _charonAngles = [angles copy];
}

- (instancetype)initCharonWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
                    highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                          isPreferred:(BOOL)preferred
{
    self = [self init];
    if (self == nil) {
        return nil;
    }
    _charonAngles = [angles copy];
    if (preferred) {
        _status = CPLaneStatusPreferred;
        _charonHighlightedAngle = highlightedAngle;
    } else if (highlightedAngle != nil) {
        _status = CPLaneStatusGood;
        _charonHighlightedAngle = highlightedAngle;
    } else {
        _status = CPLaneStatusNotGood;
        _charonHighlightedAngle = nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CPLane *lane = [[[self class] allocWithZone:zone] init];
    lane.status = _status;
    lane.primaryAngle = _primaryAngle;
    lane.secondaryAngles = _secondaryAngles;
    [lane charon_setHighlightedAngle:_charonHighlightedAngle];
    [lane charon_setAngles:_charonAngles];
    return lane;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_status forKey:@"charon.status"];
    [coder encodeObject:_primaryAngle forKey:@"charon.primaryAngle"];
    [coder encodeObject:_secondaryAngles forKey:@"charon.secondaryAngles"];
    [coder encodeObject:_charonHighlightedAngle forKey:@"charon.highlightedAngle"];
    [coder encodeObject:_charonAngles forKey:@"charon.angles"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _status = (CPLaneStatus)[coder decodeIntegerForKey:@"charon.status"];
        _primaryAngle = [coder decodeObjectOfClass:[NSMeasurement class] forKey:@"charon.primaryAngle"];
        _secondaryAngles = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSMeasurement class], nil]
                                               forKey:@"charon.secondaryAngles"];
        _charonHighlightedAngle = [coder decodeObjectOfClass:[NSMeasurement class]
                                                     forKey:@"charon.highlightedAngle"];
        _charonAngles = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSMeasurement class], nil]
                                             forKey:@"charon.angles"];
    }
    return self;
}

- (NSString *)description
{
    static NSString *const names[] = {@"NotGood", @"Good", @"Preferred"};
    NSUInteger index = (NSUInteger)_status;
    NSString *name = index < 3 ? names[index] : [NSString stringWithFormat:@"%lu", (unsigned long)index];
    return [NSString stringWithFormat:@"<CPLane: %p %@, primary %@, secondary %lu, angles %lu>",
            self, name, _primaryAngle.description ?: @"nil",
            (unsigned long)_secondaryAngles.count, (unsigned long)_charonAngles.count];
}

@end
#pragma clang diagnostic pop
