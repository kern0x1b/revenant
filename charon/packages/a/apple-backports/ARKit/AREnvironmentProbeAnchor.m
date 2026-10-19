// AREnvironmentProbeAnchor.m - a probe of the light around a point, at 12.0 with environment texturing.
//
// A probe is placed where the caller says, with the extent it covers. Its texture is rendered from the
// camera's view of the room, which is the environment texturing this port does not run: the tracker
// reports planes and a camera pose and no texture. So the probe a caller makes carries its place and its
// extent, and no session gives one a texture. See facts/ARKit/SensorShells.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation AREnvironmentProbeAnchor

@synthesize environmentTexture = _environmentTexture;
@synthesize extent = _extent;

- (instancetype)initWithName:(NSString *)name transform:(simd_float4x4)transform extent:(simd_float3)extent
{
    self = [super initWithName:name transform:transform];
    if (self)
        _extent = extent;
    return self;
}

- (instancetype)initWithTransform:(simd_float4x4)transform extent:(simd_float3)extent
{
    self = [super initWithTransform:transform];
    if (self)
        _extent = extent;
    return self;
}

@end

NS_ASSUME_NONNULL_END
