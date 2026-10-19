// ARSCNView12.m - the 12.0 members of ARSCNView, in a 12.0 category object.
//
// The shape is the tree's own for a class that gained a member after it was written: the class and its
// 11.0 members are in `ARSCNView11.m`, because `_OBJC_CLASS_$_ARSCNView` first exists at 11.0 and the
// class object belongs to the release that introduced it; the 12.0 member is a category here, in an
// object that carries 12.0's API and nothing later. `UISegmentedControl+Actions14.m` and the other
// `+…NN.m` files are the same shape.
//
// `-unprojectPoint:ontoPlaneWithTransform:` is declared at `ARSCNView.h:100` as
// `NS_REFINED_FOR_SWIFT` and `API_AVAILABLE(ios(12.0))`. The first is a Swift-side rename and the
// second an availability warning, and the build's flags silence the warning - so the declaration is
// visible at a 6.1.3 target and the method resolves. What makes the member 12.0's is the release it
// arrived in, not whether the compiler can see it.
//
// The arithmetic is the camera's: `ARCamera.h:117` declares the five-argument unprojection and
// `ARFrame.h` declares no unprojection at all, so the view asks the frame's camera - with the view's own
// size as the viewport, because the caller's point is in the view's pixels.

// The category re-implements a method the primary class declares, which is the whole point of it and
// is what this silences - the same line UISegmentedControl+Actions14.m carries.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ARSCNView (Charon12)
- (simd_float3)unprojectPoint:(CGPoint)point
         ontoPlaneWithTransform:(simd_float4x4)planeTransform;
@end

@implementation ARSCNView (Charon12)

- (simd_float3)unprojectPoint:(CGPoint)point
         ontoPlaneWithTransform:(simd_float4x4)planeTransform
{
    return [[self.session currentFrame].camera unprojectPoint:point
                              ontoPlaneWithTransform:planeTransform
                                       orientation:UIInterfaceOrientationPortrait
                                       viewportSize:self.bounds.size];
}

@end

NS_ASSUME_NONNULL_END
