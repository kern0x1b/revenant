// ARSkeleton.m - a body's joints as tracked in one frame, at 13.0: the base of the 2D and 3D skeletons.
//
// A skeleton is what body tracking reports, and this port builds no body estimator, so no session reports a
// body or a skeleton (facts/ARKit/AbsentClasses.md). The class is
// carried so its name resolves, and its two members answer what a tracked skeleton would have given: the
// definition it was made from is nil, and it has no joints. The joint-tracking query is not carried.
// facts/ARKit/AbsentClasses.md, and facts/ARKit/Skeleton.md for the joint table the definition carries.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARSkeleton

@synthesize definition = _definition;
@synthesize jointCount = _jointCount;

@end

NS_ASSUME_NONNULL_END
