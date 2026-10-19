// ARRaycast.m - the raycast vocabulary, split from ARAnchor.m because an object carries the API of
// one release: a query, a result and a tracked raycast all arrived with 16.0, beside the body and
// positional tracking configurations in ARConfiguration4.m and the skeleton's joint names in
// ARKitConstants16.m.

#import <ARKit/ARKit.h>
#import <string.h>

#import "CharonARTracker.h"
#import "CharonARKitPrivate.h"

@implementation ARRaycastQuery
{
    simd_float3 _origin;
    simd_float3 _direction;
    ARRaycastTarget _target;
    ARRaycastTargetAlignment _targetAlignment;
    NSArray<ARRaycastQuery *> *_includedQueries;
}
    @synthesize origin = _origin;
    @synthesize direction = _direction;
    @synthesize target = _target;
    @synthesize targetAlignment = _targetAlignment;



- (simd_float3)origin { return _origin; }
- (simd_float3)direction { return _direction; }
- (ARRaycastTarget)target { return _target; }
- (ARRaycastTargetAlignment)targetAlignment { return _targetAlignment; }
- (NSArray<ARRaycastQuery *> *)includedQueries { return _includedQueries; }

- (instancetype)initWithOrigin:(simd_float3)origin
                    direction:(simd_float3)direction
             allowingTarget:(ARRaycastTarget)target
                    alignment:(ARRaycastTargetAlignment)alignment
{
    self = [super init];
    if (self) {
        _origin = origin;
        _direction = direction;
        _target = target;
        _targetAlignment = alignment;
    }
    return self;
}

- (ARRaycastQuery *)simd_copy
{
    ARRaycastQuery *copy = [[ARRaycastQuery alloc] initWithOrigin:_origin
                                                      direction:_direction
                                                 allowingTarget:_target
                                                     alignment:_targetAlignment];
    return copy;
}

@end
@implementation ARRaycastResult
{
    simd_float3 _worldPosition;
    simd_float3 _localNormal;
    simd_float3 _cameraPosition;
    CGFloat _distance;
}
    @synthesize worldTransform = _worldTransform;
    @synthesize target = _target;
    @synthesize targetAlignment = _targetAlignment;
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
    _cameraPosition = ((simd_float3){0, 0, 0});
    _distance = (CGFloat)simd_length(hit.position);
    return self;
}

- (simd_float3)worldPosition { return _worldPosition; }
- (simd_float3)localNormal { return _localNormal; }
- (simd_float3)cameraPosition { return _cameraPosition; }
- (CGFloat)distance { return _distance; }

@end
@implementation ARTrackedRaycast
{
    NSMutableArray<CharonARValue *> *_rawResults;
    NSInteger _state;
    NSUUID *_identifier;
}

- (instancetype)initWithResults:(NSArray<CharonARValue *> *)results
{
    self = [super init];
    if (self) {
        _rawResults = [results copy];
        // Apple's rule, which this follows: a raycast stops being reported once the camera has moved
        // more than its own ray length, because past that the result no longer describes this frame.
        _state = 0;   // ARRaycastStateInitializing, whose enumeration the SDK refines for Swift
        _identifier = [NSUUID UUID];
    }
    return self;
}

- (void)stopTracking
{
    // Apple's rule, which this follows: a tracked raycast stops reporting once the camera has moved
    // further than its own ray length, because past that the result no longer describes this frame.
    // The caller says so, and the results go with it.
    [_rawResults removeAllObjects];
    _state = 2;   // ARRaycastStateStopped
}

- (NSUUID *)identifier { return _identifier; }
- (NSInteger)state { return _state; }
- (NSArray<ARRaycastResult *> *)results
{
    NSMutableArray<ARRaycastResult *> *out = [NSMutableArray array];
    for (CharonARValue *value in _rawResults)
        [out addObject:[[ARRaycastResult alloc] initWithHitValue:value]];
    return out;
}

@end
