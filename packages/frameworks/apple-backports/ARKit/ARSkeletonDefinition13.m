#import <Foundation/Foundation.h>

#import "RevenantARKitSkeleton.h"

@implementation ARSkeletonDefinition
{
    NSArray<NSString *> *_jointNames;
    NSArray<NSNumber *> *_parentIndices;
    NSUInteger _jointCount;
}

+ (NSArray<NSString *> *)revenant_body2DJointNames
{
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @[ @"head_joint",
                   @"neck_1_joint",
                   @"right_shoulder_1_joint",
                   @"right_forearm_joint",
                   @"right_hand_joint",
                   @"left_shoulder_1_joint",
                   @"left_forearm_joint",
                   @"left_hand_joint",
                   @"right_upLeg_joint",
                   @"right_leg_joint",
                   @"right_foot_joint",
                   @"left_upLeg_joint",
                   @"left_leg_joint",
                   @"left_foot_joint",
                   @"right_eye_joint",
                   @"left_eye_joint",
                   @"root" ];
    });
    return names;
}

+ (NSArray<NSNumber *> *)revenant_body2DParentIndices
{
    static NSArray<NSNumber *> *parents;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        parents = @[ @1, @16, @1, @2, @3, @1, @5, @6, @16, @8, @9, @16, @11, @12, @0, @0, @(-1) ];
    });
    return parents;
}

+ (ARSkeletonDefinition *)defaultBody2DSkeletonDefinition
{
    static ARSkeletonDefinition *definition;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        definition = [[self alloc] initWithRevenantJointNames:[self revenant_body2DJointNames]
                                              parentIndices:[self revenant_body2DParentIndices]];
    });
    return definition;
}

- (instancetype)initWithRevenantJointNames:(NSArray<NSString *> *)jointNames
                            parentIndices:(NSArray<NSNumber *> *)parentIndices
{
    self = [super init];
    if (self) {
        _jointNames = [jointNames copy];
        _parentIndices = [parentIndices copy];
        _jointCount = _jointNames.count;
    }
    return self;
}

- (NSArray<NSString *> *)jointNames { return _jointNames; }
- (NSArray<NSNumber *> *)parentIndices { return _parentIndices; }
- (NSUInteger)jointCount { return _jointCount; }

- (NSUInteger)indexForJointName:(ARSkeletonJointName)jointName
{
    NSUInteger index = [_jointNames indexOfObject:jointName];
    return index == NSNotFound ? NSNotFound : index;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %lu joints>", NSStringFromClass([self class]), self,
                                      (unsigned long)_jointCount];
}

@end
