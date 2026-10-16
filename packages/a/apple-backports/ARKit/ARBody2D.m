// ARBody2D.m - a body in the picture, at 13.0: its 2D skeleton and the frame it was found in.
//
// Body tracking produces one for each person it finds in a frame, and this port runs none (ARSkeleton.m), so no
// body is handed out. The class is carried so the name resolves; its one member, skeleton, is the synthesised
// accessor of the SDK's property and answers nil. facts/ARKit/AbsentClasses.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARBody2D

@synthesize skeleton = _skeleton;

@end

NS_ASSUME_NONNULL_END
