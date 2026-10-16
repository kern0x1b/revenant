// ARSkeleton3D.m - a body's joints in the room, at 13.0: the transform of each joint in the model and locally.
//
// Body tracking produces these and this port runs none (ARSkeleton.m), so no 3D skeleton is handed out. The
// class is carried so the name resolves; its two transform arrays are the synthesised accessors of the SDK's
// properties and answer nil. facts/ARKit/AbsentClasses.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARSkeleton3D

@synthesize jointModelTransforms = _jointModelTransforms;
@synthesize jointLocalTransforms = _jointLocalTransforms;

@end

NS_ASSUME_NONNULL_END
