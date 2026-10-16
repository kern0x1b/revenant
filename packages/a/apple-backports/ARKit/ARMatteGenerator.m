// ARMatteGenerator.m - the person matte of a frame, at 13.0: the stencil people occlude virtual content with.
//
// A matte is a segmentation of the people in a frame, computed with a neural network on the GPU and, for the
// depth variant, a depth map. The class is carried so the name resolves; the initialiser that takes a Metal
// device and the matte methods are not carried (facts/ARKit/AbsentClasses.md), and -init and +new inherit
// NSObject's own, as measured (facts/ARKit/NSObjectInit.md).

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARMatteGenerator

@end

NS_ASSUME_NONNULL_END
