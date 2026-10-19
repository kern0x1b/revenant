// ARSkeletonDefinition13.m - the joints a body is made of, and which of them each hangs from.
//
// The 13.0 API of ARSkeletonDefinition, in one object because an object carries the API of one
// release; the 16.0 members (`defaultBody3DSkeletonDefinition`, `neutralBodySkeleton3D`, the 3D
// transforms) are not in this file and are not claimed by it.
//
// The table is Apple's, not a skeleton's shape as one might imagine it. It was read out of ARKitCore
// in the arm64e shared cache of iOS 16.0 -- the seventeen joint names in the order the initialiser
// stores them, and the seventeen parent indices out of the constant CFArray the same initialiser
// installs -- and then checked against this Mac's own ARKit, which answers the same seventeen joints
// in the same order with the same seventeen parents. `facts/ARKit/Skeleton.md` has the addresses, both
// reads, and the controls; `tests/backports/host/arkit-skeleton` is the harness that compares them and
// requires the run to go red when either table is changed.
//
// Apple's default definition has seventeen joints. The same initialiser in the iOS 16 release builds a
// nineteen-joint one as well, with `right_ear_joint` and `left_ear_joint` appended and their two
// parents appended to match, and it takes that branch only when a runtime check of its own answers
// yes; the host takes the seventeen-joint branch, which is why seventeen is what this carries.

#import <Foundation/Foundation.h>

#import "CharonARKitSkeleton.h"

@implementation ARSkeletonDefinition
{
    NSArray<NSString *> *_jointNames;
    NSArray<NSNumber *> *_parentIndices;
    NSUInteger _jointCount;
}

/// The seventeen joints of the default two-dimensional body, and each one's parent.
///
/// The names are in the order the release has them, which is not the order a body is described in
/// from the ground up: `root` is joint 16, so a joint's parent is not always at a lower index. The
/// parent of `head_joint` is `neck_1_joint` and the parent of `neck_1_joint` is `root`, which is the
/// chain Apple's own table carries.
+ (NSArray<NSString *> *)charon_body2DJointNames
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

/// Each joint's parent, as an index into the names above, and -1 for `root`, which hangs from nothing.
+ (NSArray<NSNumber *> *)charon_body2DParentIndices
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
        definition = [[self alloc] initWithCharonJointNames:[self charon_body2DJointNames]
                                              parentIndices:[self charon_body2DParentIndices]];
    });
    return definition;
}

- (instancetype)initWithCharonJointNames:(NSArray<NSString *> *)jointNames
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
    // A name the table does not have has no index, and the release says so with the one value that
    // cannot be an index into an array of seventeen: NSNotFound.
    NSUInteger index = [_jointNames indexOfObject:jointName];
    return index == NSNotFound ? NSNotFound : index;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %lu joints>", NSStringFromClass([self class]), self,
                                      (unsigned long)_jointCount];
}

@end
