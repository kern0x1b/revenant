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
