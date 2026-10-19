// ARAnchor.m, ARPlaneGeometry.m, ARPlaneAnchor.m, ARPointCloud.m, ARHitTestResult.m,
// ARRaycastQuery.m, ARRaycastResult.m and ARTrackedRaycast.m - the things a session hands back
// about the world it is tracking.
//
// The anchors are the application's own: an application adds one at a pose, the session carries it
// into every frame at that pose, and removes it when the application says so. The plane anchors are
// the ones the detector found, and a plane's alignment stays at Apple's "not determined" because
// there is no depth sensor here to determine it from - it is a detection, and it says so.

#import <ARKit/ARKit.h>
#import <string.h>

#import "CharonARTracker.h"
#import "CharonARKitPrivate.h"

// `-[ARAnchor initWithName:transform:]` and `name` are the 12.0 vocabulary; they are served here for
// a runtime that predates them, and a caller reaching them is by definition on a release new enough.
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
    // Copying an anchor gives a new identity at the same place: a new name, a new UUID, and the
    // transform it was at, which is what a caller duplicating an anchor expects it to mean.
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

/// The header declares an anchor secure-coding, and an anchor is a name, a pose and nothing else, so
/// the two are all there is to encode.
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
    // The 6.1.3 release's own coder has no keyed `decodeValue:forKey:objCType:`, so the pose is
    // read back the way that release writes a structure: as the four columns of the matrix.
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



// `ARPlaneAnchor.geometry` is declared by the 11.3 headers and is implemented here for a runtime
// that predates them; a caller reaching it is by definition on a release new enough for the answer.
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
    // What the detector actually found, which is a level surface: the alignment is horizontal
    // because that is the surface, and it is a detection rather than a measurement because there is
    // no depth sensor here to measure one. The C surface has no "not determined" case; the Swift
    // one does, and a caller that wants it asks the framework's own question of the geometry.
    _alignment = ARPlaneAnchorAlignmentHorizontal;
    _center = plane.center;
    _extent = plane.extent;
    // The detector's own confidence in the plane is what says whether the session is still tracking
    // it: a plane it no longer has any confidence in is not being seen, and the anchor stays in the
    // world anyway because the framework keeps anchors the session has lost track of.
    _isTracked = plane.alignment > 0.0f;
    return self;
}

- (ARPlaneAnchorAlignment)alignment { return _alignment; }
- (simd_float3)center { return _center; }
- (simd_float3)extent { return _extent; }

/// Whether the session is still tracking this plane, which is the detector's confidence in it.
- (BOOL)isTracked
{
    return _isTracked;
}

+ (BOOL)isClassificationSupported
{
    // A plane's classification - floor, wall, table, ceiling - is read out of a depth sensor's
    // geometry, and this device has none, so a detector's plane is a plane and not one of those.
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
    // the tracker's samples are the same three floats a point cloud is, so the buffer is copied into
    // one this object owns and hands out in place
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
    // The framework hands out a pointer into a buffer it names itself, and a caller walks it with
    // `count` beside it; the buffer lives as long as this object does.
    return _points;
}

- (BOOL)identifier:(NSUInteger)identifier atIndex:(NSUInteger)index
{
    (void)identifier;
    (void)index;
    return NO;   // a point cloud of a monocular system has no stable indices to give back
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
    // a hit's transform is a pose, and a pose of a point is the point with no rotation
    return CharonARKitIdentityFloat4x4;
}
- (simd_float3)localPosition { return _worldPosition; }
- (simd_float3)localNormal { return _localNormal; }
- (ARPlaneAnchor *)planeAnchor { return _planeAnchor; }
- (ARAnchor *)anchor { return _anchor; }
- (CGFloat)distance { return _distance; }

@end
