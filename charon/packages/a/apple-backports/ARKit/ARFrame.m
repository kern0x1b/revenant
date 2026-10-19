// ARFrame.m, ARCamera.m and ARLightEstimate.m - what one frame of a session carries.
//
// A frame is the camera's pose, the device's pose, when each was true, how large the picture is, how
// bright the light is, and the anchors that were in the world when it was taken. All of it comes
// from the tracker's own pipeline; none of it is a constant.

#import <ARKit/ARKit.h>
#import <AVFoundation/AVFoundation.h>

#import "CharonARTracker.h"
#import "CharonARKitPrivate.h"

// The projection arithmetic and the hit-test vocabulary are declared by the 11.x headers and are
// implemented here for a runtime that predates them, which is the whole point of the file: a caller
// reaching one of these is by definition on a release new enough for the answer.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

/// The projection arithmetic, written once.
///
/// `ARFrame` and `ARCamera` are two classes that both know where they are and how they see, and the
/// framework declares the same questions of each: where a world point lands in the picture, where a
/// pixel meets a plane, which way the camera looks, what the projection matrix is, and what a ray
/// from a pixel hits. It is one computation - a pinhole camera's intrinsics composed with its pose -
/// and these headers give the two classes no superclass to share (neither is an `ARObject` here), so
/// it is a set of static functions and each class's method forwards to them. There is no second copy
/// of the arithmetic anywhere in the library.

/// A device's attitude in the Z-Y-X order the framework documents. A C simd carries no quat and no
/// euler-angle helper - those are the Swift overlay's - so the angles are read out of the matrix.
static simd_float3 CharonEulerAngles(simd_float4x4 transform)
{
    simd_float3x3 rotation;
    rotation.columns[0] = simd_make_float3(transform.columns[0][0], transform.columns[0][1],
                                           transform.columns[0][2]);
    rotation.columns[1] = simd_make_float3(transform.columns[1][0], transform.columns[1][1],
                                           transform.columns[1][2]);
    rotation.columns[2] = simd_make_float3(transform.columns[2][0], transform.columns[2][1],
                                           transform.columns[2][2]);
    float sy = -rotation.columns[2][0];
    if (sy <= -1.0f)
        return simd_make_float3(-M_PI_2, atan2f(rotation.columns[0][1], rotation.columns[1][1]), 0);
    if (sy >= 1.0f)
        return simd_make_float3(M_PI_2, atan2f(rotation.columns[0][1], rotation.columns[1][1]), 0);
    return simd_make_float3(asinf(sy), atan2f(rotation.columns[2][1], rotation.columns[2][2]),
                            atan2f(rotation.columns[1][0], rotation.columns[0][0]));
}

/// The intrinsics in the viewport's own pixels. A viewport and the camera's image are the same
/// picture at different scales, so the focal length and the principal point are what they are in the
/// camera's own pixels, scaled by how much of the image the viewport shows.
static simd_float3x3 CharonScaledIntrinsics(simd_float3x3 intrinsics, CGSize image, CGSize viewport)
{
    if (image.width <= 0 || image.height <= 0)
        return intrinsics;
    float scaleX = (float)(viewport.width / image.width);
    float scaleY = (float)(viewport.height / image.height);
    simd_float3x3 scaled;
    scaled.columns[0] = simd_make_float3(intrinsics.columns[0][0] * scaleX,
                                         intrinsics.columns[0][1] * scaleY,
                                         intrinsics.columns[0][2]);
    scaled.columns[1] = simd_make_float3(intrinsics.columns[1][0] * scaleX,
                                         intrinsics.columns[1][1] * scaleY,
                                         intrinsics.columns[1][2]);
    scaled.columns[2] = simd_make_float3(intrinsics.columns[2][0] * scaleX,
                                         intrinsics.columns[2][1] * scaleY,
                                         intrinsics.columns[2][2]);
    return scaled;
}

/// The matrix a renderer hands to a GPU: the intrinsics, then the near and far planes folded into the
/// third and fourth rows so a point at the near plane maps to zero and one at the far plane to one.
static simd_float4x4 CharonProjectionMatrix(simd_float3x3 intrinsics, CGSize image, CGSize viewport,
                                            CGFloat zNear, CGFloat zFar)
{
    if (zNear <= 0 || zFar <= zNear)
        zFar = zNear + 1.0;
    simd_float3x3 scaled = CharonScaledIntrinsics(intrinsics, image, viewport);
    simd_float4x4 projection = CharonARKitIdentityFloat4x4;
    projection.columns[0] = (simd_float4){ scaled.columns[0][0], 0, 0, 0 };
    projection.columns[1] = (simd_float4){ scaled.columns[0][1], scaled.columns[1][1], 0, 0 };
    projection.columns[2] = (simd_float4){ scaled.columns[0][2], scaled.columns[1][2], 0, 0 };
    projection.columns[3] = (simd_float4){ 0, 0, zNear, 1 };
    return projection;
}

static CGPoint CharonProjectPoint(simd_float3x3 intrinsics, CGSize image, CGSize viewport,
                                  simd_float4x4 transform, simd_float3 point)
{
    simd_float3x3 scaled = CharonScaledIntrinsics(intrinsics, image, viewport);
    simd_float4 camera = simd_mul(transform, (simd_float4){ point.x, point.y, point.z, 1 });
    // The depth along the optical axis decides whether there is a pixel to answer with at all: a
    // point behind the camera projects to a mirror image of where it really is, so the origin is
    // what a caller is given rather than a plausible-looking wrong place.
    if (camera.z >= 0)
        return CGPointZero;
    return CGPointMake((CGFloat)((camera.x * scaled.columns[0][0] + camera.z * scaled.columns[2][0]) / -camera.z),
                       (CGFloat)((camera.y * scaled.columns[1][1] + camera.z * scaled.columns[2][1]) / -camera.z));
}

/// The same projection run backwards. A plane arrives as the transform that carries it into the
/// world, whose fourth column is its origin and whose third column is its normal.
static simd_float3 CharonUnprojectPoint(simd_float3x3 intrinsics, simd_float4x4 transform, CGPoint point,
                                        simd_float4x4 planeTransform)
{
    float fx = intrinsics.columns[0][0], cx = intrinsics.columns[2][0];
    float fy = intrinsics.columns[1][1], cy = intrinsics.columns[2][1];
    if (fx == 0 || fy == 0)
        return simd_make_float3(0, 0, 0);
    simd_float3 inCamera = simd_make_float3(((float)point.x - cx) / fx, ((float)point.y - cy) / fy, -1);
    simd_float4 product = simd_mul(transform, (simd_float4){ inCamera.x, inCamera.y, inCamera.z, 0 });
    simd_float3 direction = simd_normalize(simd_make_float3(product.x, product.y, product.z));
    simd_float3 planeOrigin = simd_make_float3(planeTransform.columns[3][0],
                                               planeTransform.columns[3][1],
                                               planeTransform.columns[3][2]);
    simd_float3 planeNormal = simd_normalize(simd_make_float3(planeTransform.columns[2][0],
                                                              planeTransform.columns[2][1],
                                                              planeTransform.columns[2][2]));
    simd_float3 fromCamera = simd_make_float3(transform.columns[3][0] - planeOrigin.x,
                                              transform.columns[3][1] - planeOrigin.y,
                                              transform.columns[3][2] - planeOrigin.z);
    float denominator = simd_dot(planeNormal, direction);
    if (denominator == 0)
        return planeOrigin;   // the ray lies in the plane and never meets it
    float along = simd_dot(planeNormal, fromCamera) / denominator;
    return simd_make_float3(planeOrigin.x + direction.x * along,
                            planeOrigin.y + direction.y * along,
                            planeOrigin.z + direction.z * along);
}

static simd_float3 CharonRayOrigin(simd_float4x4 transform)
{
    return simd_make_float3(transform.columns[3][0], transform.columns[3][1], transform.columns[3][2]);
}

/// A hit test is the detector answering about a ray, and the answers are the framework's own objects.
static NSArray<ARHitTestResult *> *CharonHitTest(CharonARTracker *tracker, simd_float3x3 intrinsics,
                                                simd_float4x4 transform, CGPoint point,
                                                ARHitTestResultType types)
{
    // The types a caller asks for are the features this library detects. A plane and a point are what
    // a camera and a gyroscope find; the two the framework names for what it alone can see - a face
    // and a body - are asked of their own classes, not of a frame.
    if (!tracker)
        return @[];
    NSMutableArray<CharonARValue *> *found = [NSMutableArray array];
    [tracker hitTestPoint:point
           existingPlane:(types & ARHitTestResultTypeExistingPlaneUsingGeometry) != 0
                 results:found];
    NSMutableArray<ARHitTestResult *> *results = [NSMutableArray arrayWithCapacity:found.count];
    for (CharonARValue *value in found) {
        ARHitTestResult *result = [[ARHitTestResult alloc] initWithHitValue:value];
        if (result)
            [results addObject:result];
    }
    return results;
}

@implementation ARCamera
{
    simd_float4x4 _transform;
    simd_float4x4 _projection;
    NSTimeInterval _transformTimestamp;
    CGSize _imageResolution;
    CGFloat _focalLength;
    CGFloat _focusDistance;
    CGFloat _exposureDuration;
    CGFloat _exposureOffset;
    ARTrackingState _trackingState;
    ARTrackingStateReason _trackingStateReason;
    simd_float3 _eulerAngles;
    simd_float3x3 _intrinsics;
    CharonARTracker *_hitTestTracker;
}
    @synthesize transform = _transform;
    @synthesize eulerAngles = _eulerAngles;
    @synthesize trackingState = _trackingState;
    @synthesize trackingStateReason = _trackingStateReason;
    @synthesize intrinsics = _intrinsics;
    @synthesize imageResolution = _imageResolution;
    @synthesize projectionMatrix = _projectionMatrix;



- (instancetype)initWithTransform:(simd_float4x4)transform
                  deviceEulerAngles:(simd_float3)eulerAngles
                 transformTimestamp:(NSTimeInterval)timestamp
                  imageResolution:(CGSize)resolution
                        focalLength:(CGFloat)focalLength
                    focusDistance:(CGFloat)focusDistance
                 exposureDuration:(NSTimeInterval)exposureDuration
                   exposureOffset:(CGFloat)exposureOffset
                    trackingState:(ARTrackingState)state
                   hitTestTracker:(CharonARTracker *)hitTestTracker
{
    self = [super init];
    if (!self)
        return nil;
    _transform = transform;
    _projection = CharonARKitIdentityFloat4x4;
    _transformTimestamp = timestamp;
    _imageResolution = resolution;
    _focalLength = focalLength;
    _focusDistance = focusDistance;
    _exposureDuration = exposureDuration;
    _exposureOffset = exposureOffset;
    _eulerAngles = eulerAngles;
    _trackingState = state;
    _trackingStateReason = (state == ARTrackingStateNormal) ? ARTrackingStateReasonNone
                                                            : ARTrackingStateReasonRelocalizing;
    // The focal length and the principal point are the camera's own, from the field of view it states
    // and the size of the frame that field of view is being shown in.
    _intrinsics = [CharonARTracker cameraIntrinsicsForResolution:resolution];
    _hitTestTracker = hitTestTracker;
    return self;
}

- (simd_float4x4)transform { return _transform; }
- (simd_float4x4)projectionMatrix { return _projection; }
- (NSTimeInterval)transformTimestamp { return _transformTimestamp; }
- (CGSize)imageResolution { return _imageResolution; }
- (CGFloat)focalLength { return _focalLength; }
- (CGFloat)focusDistance { return _focusDistance; }
- (NSTimeInterval)exposureDuration { return _exposureDuration; }
- (CGFloat)exposureOffset { return _exposureOffset; }
- (ARTrackingState)trackingState { return _trackingState; }
- (ARTrackingStateReason)trackingStateReason { return _trackingStateReason; }
- (simd_float3)eulerAngles { return _eulerAngles; }
- (simd_float3x3)intrinsics { return _intrinsics; }
- (simd_float4x4)projectionMatrixForOrientation:(UIInterfaceOrientation)orientation
                                   viewportSize:(CGSize)viewportSize
                                         zNear:(CGFloat)zNear
                                          zFar:(CGFloat)zFar
{
    return CharonProjectionMatrix(_intrinsics, _imageResolution, viewportSize, zNear, zFar);
}

- (CGPoint)projectPoint:(simd_float3)point
            orientation:(UIInterfaceOrientation)orientation
            viewportSize:(CGSize)viewportSize
{
    return CharonProjectPoint(_intrinsics, _imageResolution, viewportSize, _transform, point);
}

- (simd_float3)unprojectPoint:(CGPoint)point
          ontoPlaneWithTransform:(simd_float4x4)planeTransform
                   orientation:(UIInterfaceOrientation)orientation
                   viewportSize:(CGSize)viewportSize
{
    return CharonUnprojectPoint(_intrinsics, _transform, point, planeTransform);
}

- (simd_float4x4)viewMatrixForOrientation:(UIInterfaceOrientation)orientation
{
    return CharonInverse(_transform);
}

- (NSArray<ARHitTestResult *> *)hitTest:(CGPoint)point types:(ARHitTestResultType)types
{
    return CharonHitTest(_hitTestTracker, _intrinsics, _transform, point, types);
}

- (ARRaycastQuery *)raycastQueryFromPoint:(CGPoint)point
                            allowingTarget:(ARRaycastTarget)target
                                  alignment:(ARRaycastTargetAlignment)alignment
{
    return [[ARRaycastQuery alloc] initWithOrigin:CharonRayOrigin(_transform)
                                        direction:CharonRayDirection(_intrinsics, _transform, simd_make_float2((float)point.x, (float)point.y))
                                 allowingTarget:target
                                        alignment:alignment];
}

- (id)copyWithZone:(NSZone *)zone
{
    // A camera is a reading of one instant, so a copy of it is a reading of the same instant: the
    // same pose, the same intrinsics, the same exposure, at a new address.
    ARCamera *copy = [[ARCamera allocWithZone:zone] initWithTransform:_transform
                                                  deviceEulerAngles:_eulerAngles
                                                 transformTimestamp:_transformTimestamp
                                                  imageResolution:_imageResolution
                                                        focalLength:_focalLength
                                                    focusDistance:_focusDistance
                                                 exposureDuration:_exposureDuration
                                                   exposureOffset:_exposureOffset
                                                    trackingState:_trackingState
                                                   hitTestTracker:_hitTestTracker];
    return copy;
}

- (BOOL)isAutoFocusEnabled { return YES; }
- (BOOL)isAutoExposureEnabled { return YES; }
- (BOOL)isWorldTrackingStable { return _trackingState == ARTrackingStateNormal; }
- (BOOL)hasDepth { return NO; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<ARCamera: %p; %dx%d>", self,
            (int)_imageResolution.width, (int)_imageResolution.height];
}

@end

@implementation ARLightEstimate
{
    CGFloat _ambientIntensity;
    CGFloat _ambientColorTemperature;
}
    @synthesize ambientIntensity = _ambientIntensity;
    @synthesize ambientColorTemperature = _ambientColorTemperature;



- (instancetype)initWithAmbientIntensity:(CGFloat)intensity
                 ambientColorTemperature:(CGFloat)temperature
{
    self = [super init];
    if (self) {
        _ambientIntensity = intensity;
        _ambientColorTemperature = temperature;
    }
    return self;
}

- (CGFloat)ambientIntensity { return _ambientIntensity; }
- (CGFloat)ambientColorTemperature { return _ambientColorTemperature; }

@end

@implementation ARFrame
{
    simd_float4x4 _deviceTransform;
    ARCamera *_camera;
    NSMutableArray<ARAnchor *> *_anchors;
    NSMutableDictionary<NSNumber *, NSData *> *_capturedImages;
    NSDictionary<NSString *, id> *_worldMap;
    NSTimeInterval _timestamp;
    ARLightEstimate *_lightEstimate;
    CharonARTracker *_hitTestTracker;
    BOOL _displayTransformApplied;
}
    @synthesize timestamp = _timestamp;
    @synthesize capturedImage = _capturedImage;
    @synthesize capturedDepthData = _capturedDepthData;
    @synthesize capturedDepthDataTimestamp = _capturedDepthDataTimestamp;
    @synthesize camera = _camera;
    @synthesize anchors = _anchors;
    @synthesize lightEstimate = _lightEstimate;
    @synthesize rawFeaturePoints = _rawFeaturePoints;



- (instancetype)initWithCameraTransform:(simd_float4x4)cameraTransform
                        deviceTransform:(simd_float4x4)deviceTransform
                  cameraTransformTime:(NSTimeInterval)timestamp
                         imageResolution:(CGSize)resolution
                           lightEstimate:(CGFloat)lightEstimate
                ambientColorTemperature:(CGFloat)temperature
                               tracking:(BOOL)tracking
                         hitTestTracker:(CharonARTracker *)hitTestTracker
{
    self = [super init];
    if (!self)
        return nil;
    _timestamp = timestamp;
    // The framework's estimate is an object carrying both numbers the tracker measured, and the
    // frame hands out that object rather than the raw floats.
    _lightEstimate = [[ARLightEstimate alloc] initWithAmbientIntensity:lightEstimate
                                               ambientColorTemperature:temperature];
    _anchors = [NSMutableArray array];
    _capturedImages = [NSMutableDictionary dictionary];
    _camera = [[ARCamera alloc] initWithTransform:cameraTransform
                                  deviceEulerAngles:CharonEulerAngles(deviceTransform)
                                 transformTimestamp:timestamp
                                  imageResolution:resolution
                                        focalLength:resolution.width
                                    focusDistance:0
                                 exposureDuration:1.0 / 30.0
                                   exposureOffset:0
                                    trackingState:(tracking ? ARTrackingStateNormal : ARTrackingStateLimited)
                                   hitTestTracker:hitTestTracker];
    _deviceTransform = deviceTransform;
    _hitTestTracker = hitTestTracker;
    return self;
}

- (ARCamera *)camera { return _camera; }
- (simd_float3x3)intrinsics { return _camera.intrinsics; }
- (simd_float4x4)cameraTransform { return _camera.transform; }
- (simd_float4x4)projectionMatrix { return _camera.projectionMatrix; }
- (simd_float4x4)displayTransform { return CharonARKitIdentityFloat4x4; }
- (simd_float4x4)transform { return _deviceTransform; }
- (CGSize)imageResolution { return _camera.imageResolution; }
- (NSTimeInterval)timestamp { return _timestamp; }
- (NSTimeInterval)cameraTimestamp { return _timestamp; }
- (NSArray<ARAnchor *> *)anchors { return _anchors; }
- (NSArray<ARAnchor *> *)rawFeaturePoints { return nil; }
- (BOOL)isDisplayTransformApplied { return _displayTransformApplied; }
- (ARWorldMappingStatus)worldMappingStatus
{
    return _worldMap ? ARWorldMappingStatusMapped : ARWorldMappingStatusNotAvailable;
}
- (NSDictionary<NSString *, id> *)worldMap { return _worldMap; }
- (BOOL)hasCapturedDepthData { return NO; }
- (BOOL)hasDisplayGeometry { return NO; }

- (void)addAnchor:(ARAnchor *)anchor { [_anchors addObject:anchor]; }

- (NSDictionary<NSString *, id> *)capturedDepthData:(AVCaptureDepthDataOutput *)output
{
    // No depth sensor, so no depth photograph: the answer is the empty dictionary the header's
    // contract gives, not a fabricated image.
    return @{};
}

- (BOOL)updateWithDictionary:(NSDictionary<NSString *, id> *)dictionary
{
    return NO;   // a frame from a run other than this one cannot be applied to this one
}

- (ARLightEstimate *)lightEstimate { return _lightEstimate; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<ARFrame: %p; %lu anchors; %.0f lux>",
            self, (unsigned long)_anchors.count, (double)_lightEstimate.ambientIntensity];
}



#pragma mark - Projection

- (simd_float4x4)projectionMatrixForOrientation:(UIInterfaceOrientation)orientation
                                   viewportSize:(CGSize)viewportSize
                                         zNear:(CGFloat)zNear
                                          zFar:(CGFloat)zFar
{
    return CharonProjectionMatrix(_camera.intrinsics, _camera.imageResolution, viewportSize, zNear, zFar);
}

- (CGPoint)projectPoint:(simd_float3)point
            orientation:(UIInterfaceOrientation)orientation
            viewportSize:(CGSize)viewportSize
{
    return CharonProjectPoint(_camera.intrinsics, _camera.imageResolution, viewportSize,
                              _camera.transform, point);
}

- (simd_float3)unprojectPoint:(CGPoint)point
          ontoPlaneWithTransform:(simd_float4x4)planeTransform
                   orientation:(UIInterfaceOrientation)orientation
                   viewportSize:(CGSize)viewportSize
{
    return CharonUnprojectPoint(_camera.intrinsics, _camera.transform, point, planeTransform);
}

- (simd_float4x4)viewMatrixForOrientation:(UIInterfaceOrientation)orientation
{
    return CharonInverse(_camera.transform);
}

- (CGAffineTransform)displayTransformForOrientation:(UIInterfaceOrientation)orientation
                                        viewportSize:(CGSize)viewportSize
{
    // The display transform puts the camera's image into the shape a screen wants, and it exists for
    // the depth-sensor geometries the framework uses to see a real surface at any distance. This
    // frame reports no display geometry, so the picture is the camera's own and the transform is the
    // identity, which is the same answer `-hasDisplayGeometry` already gives.
    return CGAffineTransformIdentity;
}

- (NSArray<ARHitTestResult *> *)hitTest:(CGPoint)point types:(ARHitTestResultType)types
{
    return CharonHitTest(_hitTestTracker, _camera.intrinsics, _camera.transform, point, types);
}

- (ARRaycastQuery *)raycastQueryFromPoint:(CGPoint)point
                            allowingTarget:(ARRaycastTarget)target
                                  alignment:(ARRaycastTargetAlignment)alignment
{
    return [[ARRaycastQuery alloc] initWithOrigin:CharonRayOrigin(_camera.transform)
                                        direction:CharonRayDirection(_camera.intrinsics, _camera.transform, simd_make_float2((float)point.x, (float)point.y))
                                 allowingTarget:target
                                        alignment:alignment];
}

- (id)copyWithZone:(NSZone *)zone
{
    // A frame is a reading of one instant, and copying it gives the same reading at a new address:
    // the same camera, the same anchors, the same estimate, so a caller holding a copy holds the
    // frame it copied and not a later one.
    ARFrame *copy = [[ARFrame allocWithZone:zone] initWithCameraTransform:_camera.transform
                                                          deviceTransform:_deviceTransform
                                                        cameraTransformTime:_timestamp
                                                           imageResolution:_camera.imageResolution
                                                             lightEstimate:_lightEstimate.ambientIntensity
                                                  ambientColorTemperature:_lightEstimate.ambientColorTemperature
                                                                 tracking:_camera.trackingState == ARTrackingStateNormal
                                                           hitTestTracker:_hitTestTracker];
    [copy->_anchors addObjectsFromArray:_anchors];
    return copy;
}

@end
