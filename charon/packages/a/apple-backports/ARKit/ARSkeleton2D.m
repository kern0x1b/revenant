// ARSkeleton2D.m - a body's joints in the picture, at 13.0: where each joint is in the frame, in pixels.
//
// Body tracking produces these and this port runs none (ARSkeleton.m), so no 2D skeleton is handed out. The
// class is carried so the name resolves; its one member answers the zero value the SDK's property has no
// tracked joints for. facts/ARKit/AbsentClasses.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARSkeleton2D

@synthesize jointLandmarks = _jointLandmarks;

@end

NS_ASSUME_NONNULL_END
