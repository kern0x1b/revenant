#import <ARKit/ARKit.h>
#import <string.h>

#import "CharonARTracker.h"
#import "CharonARKitPrivate.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@interface ARAnchor (CharonConforms) <ARAnchorCopying>
@end

@interface ARPlaneAnchor (CharonConforms) <ARTrackable>
@end

@implementation ARAnchor
{
    simd_float4x4 _transform;
}


    @synthesize identifier = _identifier;
    @synthesize transform = _transform;
- (instancetype)initWithName:(NSString *)name transform:(simd_float4x4)transform
{
    self = [super init];
    if (!self)
        return nil;
    _identifier = [[NSUUID alloc] init];
    _name = [name copy];
    _transform = transform;
    return self;
}

- (instancetype)initWithAnchor:(ARAnchor *)anchor
{
    if (![anchor isKindOfClass:[ARAnchor class]])
        return nil;
    return [self initWithName:anchor.name transform:anchor.transform];
}

- (id)copyWithZone:(NSZone *)zone
{
    ARAnchor *copy = [[self class] allocWithZone:zone];
    copy->_identifier = _identifier;
    copy->_name = _name;
    copy->_transform = _transform;
    return copy;
}

- (ARAnchor *)anchorByApplyingOrigin:(simd_float4x4)origin
{
    ARAnchor *moved = [[ARAnchor alloc] initWithName:_name transform:simd_mul(origin, _transform)];
    moved->_identifier = _identifier;
    return moved;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_name forKey:@"name"];
    CharonEncodeStruct(coder, @"transform", &_transform, sizeof _transform);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _identifier = [coder decodeObjectOfClass:[NSUUID class] forKey:@"identifier"] ?: [NSUUID UUID];
    _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
    CharonDecodeStruct(coder, @"transform", &_transform, sizeof _transform);
    return self;
}


- (instancetype)initWithIdentifier:(NSUUID *)identifier transform:(simd_float4x4)transform
{
    self = [super init];
    if (!self)
        return nil;
    _identifier = [identifier copy] ?: [NSUUID UUID];
    _transform = transform;
    return self;
}

- (instancetype)initWithTransform:(simd_float4x4)transform
{
    return [self initWithIdentifier:[NSUUID UUID] transform:transform];
}

- (simd_float4x4)transform { return _transform; }

- (BOOL)isEqualToAnchor:(ARAnchor *)anchor
{
    if (![anchor isKindOfClass:[ARAnchor class]])
        return NO;
    return [_identifier isEqual:anchor.identifier] && simd_equal(_transform, anchor.transform);
}

- (NSUInteger)hash
{
    return [_identifier hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; %@>", NSStringFromClass([self class]), self, _identifier];
}

@end



#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@implementation ARPlaneAnchor
{
    ARPlaneAnchorAlignment _alignment;
    simd_float3 _center;
    simd_float3 _extent;
    ARPlaneGeometry *_geometry;
    BOOL _isTracked;
}
    @synthesize alignment = _alignment;
    @synthesize center = _center;



- (instancetype)initWithPlaneValue:(CharonARValue *)value
{
    CharonARPlane plane;
    [value getValue:&plane];
    self = [super initWithIdentifier:[NSUUID UUID] transform:CharonARKitIdentityFloat4x4];
    if (!self)
        return nil;
    _alignment = ARPlaneAnchorAlignmentHorizontal;
    _center = plane.center;
    _extent = plane.extent;
    _isTracked = plane.alignment > 0.0f;
    return self;
}

- (ARPlaneAnchorAlignment)alignment { return _alignment; }
- (simd_float3)center { return _center; }
- (simd_float3)extent { return _extent; }

- (BOOL)isTracked
{
    return _isTracked;
}

+ (BOOL)isClassificationSupported
{
    return NO;
}

- (ARPlaneClassificationStatus)classificationStatus
{
    return ARPlaneClassificationStatusUnknown;
}

- (ARPlaneClassification)classification
{
    return ARPlaneClassificationNone;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeInteger:(NSInteger)_alignment forKey:@"alignment"];
    CharonEncodeStruct(coder, @"center", &_center, sizeof _center);
    CharonEncodeStruct(coder, @"extent", &_extent, sizeof _extent);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self)
        return nil;
    _alignment = (ARPlaneAnchorAlignment)[coder decodeIntegerForKey:@"alignment"];
    CharonDecodeStruct(coder, @"center", &_center, sizeof _center);
    CharonDecodeStruct(coder, @"extent", &_extent, sizeof _extent);
    return self;
}

- (ARPlaneGeometry *)geometry
{
    if (!_geometry) {
        CharonARPlane plane;
        memset(&plane, 0, sizeof(plane));
        plane.center = _center;
        plane.extent = _extent;
        plane.normal = ((simd_float3){0, 1, 0});
        plane.identifier = 0;
        plane.alignment = 0;
        CharonARValue *value = [[CharonARValue alloc] initWithBytes:&plane size:sizeof plane];
        _geometry = [[ARPlaneGeometry alloc] initWithPlaneValue:value];
    }
    return _geometry;
}

@end

#pragma clang diagnostic pop

@implementation ARPointCloud
{
    simd_float3 *_points;
    NSUInteger _count;
}
    @synthesize count = _count;
    @synthesize points = _points;
    @synthesize identifiers = _identifiers;



- (instancetype)initWithPoints:(NSData *)points count:(NSUInteger)count
{
    self = [super init];
    if (!self)
        return nil;
    _count = MIN(count, points.length / sizeof(simd_float3));
    _points = malloc(_count * sizeof * _points);
    if (!_points)
        return nil;
    memcpy(_points, points.bytes, _count * sizeof * _points);
    return self;
}

- (void)dealloc
{
    free(_points);
}

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_count forKey:@"count"];
    CharonEncodeStruct(coder, @"points", _points, _count * sizeof * _points);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _count = (NSUInteger)[coder decodeIntegerForKey:@"count"];
    if (!_count)
        return nil;
    _points = malloc(_count * sizeof * _points);
    if (!_points || !CharonDecodeStruct(coder, @"points", _points, _count * sizeof * _points)) {
        free(_points);
        _points = NULL;
        _count = 0;
        return nil;
    }
    return self;
}

- (NSUInteger)count { return _count; }

- (const simd_float3 *)points
{
    return _points;
}

- (BOOL)identifier:(NSUInteger)identifier atIndex:(NSUInteger)index
{
    (void)identifier;
    (void)index;
    return NO;
}

@end

@implementation ARHitTestResult
{
    simd_float3 _worldPosition;
    simd_float3 _localNormal;
    ARHitTestResultType _type;
    ARPlaneAnchor *_planeAnchor;
    ARAnchor *_anchor;
    CGFloat _distance;
}
    @synthesize type = _type;
    @synthesize distance = _distance;
    @synthesize localTransform = _localTransform;
    @synthesize worldTransform = _worldTransform;
    @synthesize anchor = _anchor;



- (instancetype)initWithHitValue:(CharonARValue *)value
{
    self = [super init];
    if (!self)
        return nil;
    CharonARHit hit;
    [value getValue:&hit];
    _worldPosition = hit.position;
    _localNormal = hit.localNormal;
    _type = (hit.planeIdentifier == 0) ? ARHitTestResultTypeFeaturePoint
                                       : ARHitTestResultTypeEstimatedHorizontalPlane;
    return self;
}

- (ARHitTestResultType)type { return _type; }
- (simd_float4x4)worldTransform
{
    return CharonARKitIdentityFloat4x4;
}
- (simd_float3)localPosition { return _worldPosition; }
- (simd_float3)localNormal { return _localNormal; }
- (ARPlaneAnchor *)planeAnchor { return _planeAnchor; }
- (ARAnchor *)anchor { return _anchor; }
- (CGFloat)distance { return _distance; }

@end
