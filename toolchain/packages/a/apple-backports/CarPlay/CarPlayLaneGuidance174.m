#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>
#import "CharonCarPlay174.h"

@implementation CPLaneGuidance {
    NSArray<CPLane *> *_lanes;
    NSArray<NSString *> *_instructionVariants;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (NSArray<CPLane *> *)lanes
{
    return _lanes;
}

- (void)setLanes:(NSArray<CPLane *> *)lanes
{
    _lanes = [lanes copy];
}

- (NSArray<NSString *> *)instructionVariants
{
    return _instructionVariants;
}

- (void)setInstructionVariants:(NSArray<NSString *> *)instructionVariants
{
    _instructionVariants = [instructionVariants copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    CPLaneGuidance *guidance = [[[self class] allocWithZone:zone] init];
    guidance.lanes = _lanes;
    guidance.instructionVariants = _instructionVariants;
    return guidance;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_lanes forKey:@"charon.lanes"];
    [coder encodeObject:_instructionVariants forKey:@"charon.instructionVariants"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _lanes = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [CPLane class], nil] forKey:@"charon.lanes"];
        _instructionVariants = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSString class], nil]
                                                    forKey:@"charon.instructionVariants"];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CPLaneGuidance: %p, %lu lanes, %lu variants>", self,
            (unsigned long)_lanes.count, (unsigned long)_instructionVariants.count];
}

@end
