#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ARSCNView (Revenant12)
- (simd_float3)unprojectPoint:(CGPoint)point
         ontoPlaneWithTransform:(simd_float4x4)planeTransform;
@end

@implementation ARSCNView (Revenant12)

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
