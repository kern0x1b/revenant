#import <ARKit/ARKit.h>

#import "CharonARKitPrivate.h"

@interface ARWorldMap ()
@property (nonatomic, strong) ARPointCloud *rawFeaturePoints;
@property (nonatomic, copy, nullable) NSData *trackerState;
@end

@implementation ARWorldMap

- (instancetype)initWithAnchors:(NSArray<ARAnchor *> *)anchors
                   featurePoints:(nullable ARPointCloud *)featurePoints
{
    self = [super init];
    if (!self)
        return nil;
    _anchors = [anchors copy];
    _rawFeaturePoints = featurePoints;
    return self;
}

@synthesize center = _center;
@synthesize extent = _extent;
@synthesize anchors = _anchors;
@synthesize trackerState = _trackerState;
@synthesize rawFeaturePoints = _rawFeaturePoints;

- (id)copyWithZone:(NSZone *)zone
{
    ARWorldMap *copy = [[ARWorldMap allocWithZone:zone] initWithAnchors:_anchors featurePoints:_rawFeaturePoints];
    copy.trackerState = _trackerState;
    return copy;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_anchors forKey:@"anchors"];
    [coder encodeObject:_trackerState forKey:@"trackerState"];
    [coder encodeInteger:(NSInteger)_rawFeaturePoints.count forKey:@"pointCount"];
    if (_rawFeaturePoints.count)
        [coder encodeBytes:(const uint8_t *)_rawFeaturePoints.points
                    length:_rawFeaturePoints.count * sizeof(simd_float3)
                    forKey:@"points"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    NSSet *anchorClasses = [NSSet setWithObjects:[ARAnchor class], [ARPlaneAnchor class], nil];
    _anchors = [coder decodeObjectOfClasses:anchorClasses forKey:@"anchors"] ?: @[];
    _trackerState = [coder decodeObjectOfClass:[NSData class] forKey:@"trackerState"];
    NSUInteger count = (NSUInteger)[coder decodeIntegerForKey:@"pointCount"];
    if (count) {
        NSMutableData *points = [NSMutableData dataWithLength:count * sizeof(simd_float3)];
        const uint8_t *decoded = [coder decodeBytesForKey:@"points" returnedLength:NULL];
        if (decoded) {
            memcpy(points.mutableBytes, decoded, points.length);
            _rawFeaturePoints = [[ARPointCloud alloc] initWithPoints:points count:count];
        }
    }
    return self;
}

- (simd_float3)center
{
    if (_anchors.count == 0)
        return simd_make_float3(0, 0, 0);
    simd_float3 sum = simd_make_float3(0, 0, 0);
    for (ARAnchor *anchor in _anchors) {
        simd_float4x4 transform = anchor.transform;
        sum.x += transform.columns[3][0];
        sum.y += transform.columns[3][1];
        sum.z += transform.columns[3][2];
    }
    float count = (float)_anchors.count;
    return simd_make_float3(sum.x / count, sum.y / count, sum.z / count);
}

- (simd_float3)extent
{
    if (_anchors.count == 0)
        return simd_make_float3(0, 0, 0);
    simd_float3 centre = self.center;
    simd_float3 high = simd_make_float3(0, 0, 0);
    simd_float3 low = simd_make_float3(0, 0, 0);
    BOOL first = YES;
    for (ARAnchor *anchor in _anchors) {
        simd_float4x4 transform = anchor.transform;
        simd_float3 position = simd_make_float3(transform.columns[3][0] - centre.x,
                                                transform.columns[3][1] - centre.y,
                                                transform.columns[3][2] - centre.z);
        if (first) {
            high = low = position;
            first = NO;
            continue;
        }
        high = simd_make_float3(MAX(high.x, position.x), MAX(high.y, position.y), MAX(high.z, position.z));
        low = simd_make_float3(MIN(low.x, position.x), MIN(low.y, position.y), MIN(low.z, position.z));
    }
    return simd_make_float3((high.x - low.x) * 0.5f, (high.y - low.y) * 0.5f, (high.z - low.z) * 0.5f);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; %lu anchors>",
            NSStringFromClass([self class]), self, (unsigned long)_anchors.count];
}

@end
