#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlay174.h"
#import "RevenantCarPlayLane.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CPLane {
    CPLaneStatus _status;
    NSMeasurement<NSUnitAngle *> *_primaryAngle;
    NSArray<NSMeasurement<NSUnitAngle *> *> *_secondaryAngles;
    NSMeasurement<NSUnitAngle *> *_revenantHighlightedAngle;
    NSArray<NSMeasurement<NSUnitAngle *> *> *_revenantAngles;
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

- (NSMeasurement<NSUnitAngle *> *)revenant_highlightedAngle
{
    return _revenantHighlightedAngle;
}

- (void)revenant_setHighlightedAngle:(NSMeasurement<NSUnitAngle *> *)angle
{
    _revenantHighlightedAngle = angle;
}

- (NSArray<NSMeasurement<NSUnitAngle *> *> *)revenant_angles
{
    return _revenantAngles;
}

- (void)revenant_setAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    _revenantAngles = [angles copy];
}

- (instancetype)initRevenantWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
                    highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                          isPreferred:(BOOL)preferred
{
    self = [self init];
    if (self == nil) {
        return nil;
    }
    _revenantAngles = [angles copy];
    if (preferred) {
        _status = CPLaneStatusPreferred;
        _revenantHighlightedAngle = highlightedAngle;
    } else if (highlightedAngle != nil) {
        _status = CPLaneStatusGood;
        _revenantHighlightedAngle = highlightedAngle;
    } else {
        _status = CPLaneStatusNotGood;
        _revenantHighlightedAngle = nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CPLane *lane = [[[self class] allocWithZone:zone] init];
    lane.status = _status;
    lane.primaryAngle = _primaryAngle;
    lane.secondaryAngles = _secondaryAngles;
    [lane revenant_setHighlightedAngle:_revenantHighlightedAngle];
    [lane revenant_setAngles:_revenantAngles];
    return lane;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_status forKey:@"revenant.status"];
    [coder encodeObject:_primaryAngle forKey:@"revenant.primaryAngle"];
    [coder encodeObject:_secondaryAngles forKey:@"revenant.secondaryAngles"];
    [coder encodeObject:_revenantHighlightedAngle forKey:@"revenant.highlightedAngle"];
    [coder encodeObject:_revenantAngles forKey:@"revenant.angles"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _status = (CPLaneStatus)[coder decodeIntegerForKey:@"revenant.status"];
        _primaryAngle = [coder decodeObjectOfClass:[NSMeasurement class] forKey:@"revenant.primaryAngle"];
        _secondaryAngles = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSMeasurement class], nil]
                                               forKey:@"revenant.secondaryAngles"];
        _revenantHighlightedAngle = [coder decodeObjectOfClass:[NSMeasurement class]
                                                     forKey:@"revenant.highlightedAngle"];
        _revenantAngles = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSMeasurement class], nil]
                                             forKey:@"revenant.angles"];
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
            (unsigned long)_secondaryAngles.count, (unsigned long)_revenantAngles.count];
}

@end
#pragma clang diagnostic pop
