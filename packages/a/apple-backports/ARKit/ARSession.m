// ARSession.m - the session: it owns the camera and the gyroscope, and it hands the application one
// frame at a time with the camera's pose, the points it has found and the planes it has detected in
// them.
//
// The run loop is the release's own `AVCaptureVideoDataOutput` and `CMMotionManager`, read through
// the tracker's pipeline. Frames arrive on the capture queue; the delegate is called on the queue the
// application named, or on the main queue as the header says.

#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>

#import "CharonARTracker.h"
#import "CharonARKitPrivate.h"

// The hit-test types arrived with iOS 11.3 and the raycast with iOS 13, both after the release's own
// ARKit; the backport carries them with the header's own guard.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@interface ARSession () <CharonARTrackerDelegate>
@end

@implementation ARSession
{
    CharonARTracker *_tracker;
    NSOperationQueue *_captureQueue;
    NSMutableArray<ARAnchor *> *_anchors;
    NSMutableArray<ARAnchor *> *_pending;
    NSUUID *_identifier;
    ARConfiguration *_configuration;
    ARSessionRunOptions _runOptions;
    simd_float4x4 _worldOrigin;
    NSMutableArray *_trackedRaycasts;
}
    @synthesize delegate = _delegate;
    @synthesize delegateQueue = _delegateQueue;
    @synthesize currentFrame = _currentFrame;
    @synthesize configuration = _configuration;



- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    _tracker = [[CharonARTracker alloc] init];
    _tracker.delegate = self;
    _anchors = [NSMutableArray array];
    _pending = [NSMutableArray array];
    _identifier = [NSUUID UUID];
    _captureQueue = [[NSOperationQueue alloc] init];
    _captureQueue.maxConcurrentOperationCount = 1;
    _captureQueue.name = @"space.kern0x1b.arkit.capture";
    _trackedRaycasts = [NSMutableArray array];
    _worldOrigin = CharonARKitIdentityFloat4x4;
    return self;
}

- (void)dealloc
{
    [_tracker stop];
    _captureQueue = nil;
}

- (NSUUID *)identifier { return _identifier; }

- (ARConfiguration *)configuration { return _configuration; }
- (ARFrame *)currentFrame { return nil; }

#pragma mark - Running

- (void)runWithConfiguration:(ARConfiguration *)configuration
{
    [self runWithConfiguration:configuration options:(ARSessionRunOptions)0];
}

- (void)runWithConfiguration:(ARConfiguration *)configuration options:(ARSessionRunOptions)options
{
    if (![[configuration class] isSupported]) {
        // The session does not start, and the application is told why through the same channel as a tracker that
        // fails to start. The error carries the framework's domain and code; it has no user info, since the port
        // knows no more about the refusal than the code says.
        NSError *unsupported = [NSError errorWithDomain:ARErrorDomain
                                                   code:ARErrorCodeUnsupportedConfiguration
                                               userInfo:nil];
        if ([_delegate respondsToSelector:@selector(session:didFailWithError:)])
            [_delegate session:self didFailWithError:unsupported];
        return;
    }
    [_tracker stop];
    NSError *error = nil;
    if (![_tracker startWithError:&error]) {
        // The hardware said no, so the application is told through the same channel it uses for
        // everything else, and the session stays paused.
        _configuration = configuration;
        if ([_delegate respondsToSelector:@selector(session:didFailWithError:)])
            [_delegate session:self didFailWithError:error];
        return;
    }
    _configuration = configuration;
    _runOptions = options;
    if (options & ARSessionRunOptionResetTracking) {
        [_tracker stop];
        [_tracker startWithError:NULL];
    }
    if (options & ARSessionRunOptionRemoveExistingAnchors)
        [_anchors removeAllObjects];
    if ([_delegate respondsToSelector:@selector(session:didUpdateFrame:)])
        ;   // the first frame is delivered by the tracker's first update
}

- (void)pause
{
    [_tracker stop];
}

#pragma mark - Anchors

- (void)addAnchor:(ARAnchor *)anchor
{
    if (anchor)
        [_pending addObject:anchor];
}

- (void)removeAnchor:(ARAnchor *)anchor
{
    if (!anchor)
        return;
    [_pending removeObject:anchor];
    [_anchors removeObject:anchor];
}

#pragma mark - What the tracker reports

- (void)tracker:(CharonARTracker *)tracker didUpdateWithTimestamp:(NSTimeInterval)timestamp
{
    // Whatever was added since the last frame is now part of the world, and the application's own
    // anchors are handed back with it.
    NSArray<ARAnchor *> *added = [_pending copy];
    [_pending removeAllObjects];
    for (ARAnchor *anchor in added) {
        anchor.identifier = [NSUUID UUID];
        [_anchors addObject:anchor];
    }

    ARFrame *frame = [[ARFrame alloc] initWithCameraTransform:tracker.cameraTransform
                                                deviceTransform:tracker.deviceTransform
                                                   cameraTransformTime:timestamp
                                                   imageResolution:tracker.imageResolution
                                                        lightEstimate:tracker.lightEstimate
                                              ambientColorTemperature:tracker.ambientColorTemperature
                                                        tracking:tracker.isTracking
                                                  hitTestTracker:tracker];
    for (ARPlaneAnchor *plane in [self planeAnchorsForTracker:tracker])
        [frame addAnchor:plane];

    [self updateTrackedRaycastsForFrame:frame];

    dispatch_queue_t queue = _delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        if ([self.delegate respondsToSelector:@selector(session:didUpdateFrame:)])
            [self.delegate session:self didUpdateFrame:frame];
        if ([self.delegate respondsToSelector:@selector(session:didAddAnchors:)])
            [self.delegate session:self didAddAnchors:added];
    });
}

/// The planes the detector found, as the plane anchors an application subscribes to. They are
/// detected, never measured: there is no depth sensor behind them, and a plane anchor's alignment
/// is left at Apple's "not determined" because there is nothing to determine it from.
- (NSArray<ARPlaneAnchor *> *)planeAnchorsForTracker:(CharonARTracker *)tracker
{
    NSMutableArray<ARPlaneAnchor *> *out = [NSMutableArray array];
    for (CharonARValue *value in tracker.planes) {
        [out addObject:[[ARPlaneAnchor alloc] initWithPlaneValue:value]];
    }
    return out;
}

/// The anchors a session is carrying: the application's own, plus the planes the detector found in
/// the tracker's world as it stands now.
- (NSArray<ARAnchor *> *)anchors
{
    // Everything in the world is expressed in the frame the origin sits in, so the origin is applied
    // as the anchors are handed out. An anchor's own transform is readonly - the application placed
    // it where it placed it - and the session is what moves the world under it.
    NSMutableArray<ARAnchor *> *out = [NSMutableArray arrayWithCapacity:_anchors.count];
    for (ARAnchor *anchor in _anchors)
        [out addObject:[[anchor copyWithZone:NULL] anchorByApplyingOrigin:_worldOrigin]];
    [out addObjectsFromArray:[self planeAnchorsForTracker:_tracker]];
    return out;
}

/// The plane anchors re-derived from the tracker, which owns the pose the camera is at.
- (void)reloadAnchorsFromTracker
{
    for (ARPlaneAnchor *plane in [self planeAnchorsForTracker:_tracker])
        [_pending addObject:plane];
}

/// A frame carrying a picture, which is what a high-resolution frame is: this session's own frame
/// at the still output's resolution.
- (ARFrame *)frameWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CharonARTracker *tracker = _tracker;
    return [[ARFrame alloc] initWithCameraTransform:tracker.cameraTransform
                                    deviceTransform:tracker.deviceTransform
                              cameraTransformTime:tracker.timestamp
                                     imageResolution:tracker.imageResolution
                                       lightEstimate:tracker.lightEstimate
                            ambientColorTemperature:tracker.ambientColorTemperature
                                           tracking:tracker.isTracking
                                     hitTestTracker:tracker];
}

/// A tracked raycast, kept so that each frame's results can be handed to its handler and so that a
/// stopped one stops being cast.
- (void)registerTrackedRaycast:(ARTrackedRaycast *)tracked
                 updateHandler:(void (^)(NSArray<ARRaycastResult *> *))updateHandler
{
    [_trackedRaycasts addObject:@{ @"raycast": tracked, @"handler": [updateHandler copy] }];
}

/// Each tracked raycast is cast again for this frame and its handler called with what it hit, which
/// is what a tracked raycast is: a ray the session keeps casting rather than one cast once.
///
/// Apple's rule for when one stops: once the camera has moved further than the ray is long, because
/// past that the result no longer describes what is in front of the camera. The ray's length here is
/// the distance from its origin to the farthest plane the detector has found along it, so that is
/// what the camera's travel is measured against.
- (void)updateTrackedRaycastsForFrame:(ARFrame *)frame
{
    simd_float3 eye = simd_make_float3(frame.camera.transform.columns[3][0],
                                      frame.camera.transform.columns[3][1],
                                      frame.camera.transform.columns[3][2]);
    NSMutableArray *survivors = [NSMutableArray arrayWithCapacity:_trackedRaycasts.count];
    for (NSDictionary *entry in _trackedRaycasts) {
        ARTrackedRaycast *tracked = entry[@"raycast"];
        void (^handler)(NSArray<ARRaycastResult *> *) = entry[@"handler"];
        NSArray<ARRaycastResult *> *hits = [self raycast:tracked.query];
        handler(hits);

        NSArray<NSNumber *> *last = entry[@"lastPosition"];
        simd_float3 from = simd_make_float3(last[0].floatValue, last[1].floatValue, last[2].floatValue);
        simd_float3 travelled = simd_make_float3(eye.x - from.x, eye.y - from.y, eye.z - from.z);
        float moved = simd_length(travelled);
        float rayLength = [self rayLengthForQuery:tracked.query results:hits];
        if (moved > rayLength) {
            [tracked stopTracking];
            continue;   // a stopped raycast is not cast again
        }
        [survivors addObject:@{ @"raycast": tracked, @"handler": handler,
                                @"lastPosition": @[ @(eye.x), @(eye.y), @(eye.z) ] }];
    }
    _trackedRaycasts = survivors;
}

/// How far the ray of a query reaches: as far as the farthest thing it hit, or a ray the detector
/// found no plane along is one that goes as far as a session's world does.
- (float)rayLengthForQuery:(ARRaycastQuery *)query results:(NSArray<ARRaycastResult *> *)results
{
    float farthest = 0;
    for (ARRaycastResult *result in results) {
        simd_float4x4 world = result.worldTransform;
        simd_float3 hit = simd_make_float3(world.columns[3][0], world.columns[3][1],
                                          world.columns[3][2]);
        simd_float3 reach = simd_make_float3(hit.x - query.origin.x, hit.y - query.origin.y,
                                             hit.z - query.origin.z);
        farthest = MAX(farthest, simd_length(reach));
    }
    if (farthest > 0)
        return farthest;
    return (float)MAX(_tracker.planes.count, 1) * 10.0f;
}

#pragma mark - What an application asks the session to do

- (void)hitTestPoint:(CGPoint)point
        types:(ARHitTestResultType)types
       results:(NSMutableArray<ARHitTestResult *> *)results
{
    NSMutableArray<CharonARValue *> *hits = [NSMutableArray array];
    if (types & ARHitTestResultTypeFeaturePoint)
        [_tracker hitTestPoint:point results:hits];
    if (types & (ARHitTestResultTypeExistingPlaneUsingGeometry |
                 ARHitTestResultTypeEstimatedHorizontalPlane |
                 ARHitTestResultTypeEstimatedVerticalPlane))
        [_tracker hitTestPoint:point existingPlane:YES results:hits];
    for (CharonARValue *value in hits)
        [results addObject:[[ARHitTestResult alloc] initWithHitValue:value]];
}

- (void)raycastWithQuery:(ARRaycastQuery *)query
              results:(NSMutableArray<ARRaycastResult *> *)results
{
    NSMutableArray<CharonARValue *> *hits = [NSMutableArray array];
    // The SDK's own spelling: the ray starts at a point of the world and runs along a direction of it.
    [_tracker raycastFromOrigin:query.origin direction:query.direction
                         allowing:query.target results:hits];
    for (CharonARValue *value in hits)
        [results addObject:[[ARRaycastResult alloc] initWithHitValue:value]];
}

#pragma mark - The world

- (void)setWorldOrigin:(simd_float4x4)relativeTransform
{
    // Moving the world origin is a change of frame for everything already in the world, so the
    // anchors the application added move with it and the ones the detector found are re-derived
    // from the tracker, which owns the pose the camera is actually at.
    _worldOrigin = relativeTransform;
    [self reloadAnchorsFromTracker];
}

- (void)getCurrentWorldMapWithCompletionHandler:(void (^)(ARWorldMap *, NSError *))completionHandler
{
    if (!completionHandler)
        return;
    dispatch_queue_t queue = _delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        // The map is what the session has: the anchors the application added, the planes the
        // detector found, and the points behind them. Handing it back is handing back that, and a
        // paused session has a map of the world as it was when it stopped.
        ARPointCloud *points = [[ARPointCloud alloc] initWithPoints:_tracker.pointCloud
                                                             count:_tracker.pointCloud.length / sizeof(simd_float3)];
        completionHandler([[ARWorldMap alloc] initWithAnchors:self.anchors
                                              featurePoints:points], nil);
    });
}

- (void)createReferenceObjectWithTransform:(simd_float4x4)transform
                                    center:(simd_float3)center
                                    extent:(simd_float3)extent
                         completionHandler:(void (^)(ARReferenceObject *, NSError *))completionHandler
{
    if (!completionHandler)
        return;
    dispatch_queue_t queue = _delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        // A reference object is a scanned mesh of a real object, and a mesh comes out of a depth
        // sensor. This device has none, so there is no mesh to scan and the caller is told so
        // through the channel the framework's own completion handler is for, rather than being
        // handed an empty object that would place a camera inside nothing.
        NSError *error = [NSError errorWithDomain:@"space.kern0x1b.arkit" code:4
                                          userInfo:@{ NSLocalizedDescriptionKey:
                                                      @"a reference object is a depth-sensor scan, and this device has no depth sensor" }];
        completionHandler(nil, error);
    });
}

- (void)getGeoLocationForPoint:(simd_float3)position
             completionHandler:(void (^)(CLLocationCoordinate2D, CLLocationDistance, NSError *))completionHandler
{
    if (!completionHandler)
        return;
    dispatch_queue_t queue = _delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        // A world point becomes a coordinate on the Earth only when the world is anchored to the
        // Earth, which is what a geo-tracking session's geolocation origin is. There is no such
        // origin on this device: the configuration that would supply it needs the location service
        // and Apple's own geolocation anchor store, and neither is asked for on a device that has
        // no depth sensor to place one against.
        (void)position;
        NSError *error = [NSError errorWithDomain:@"space.kern0x1b.arkit" code:5
                                          userInfo:@{ NSLocalizedDescriptionKey:
                                                      @"this session has no geolocation origin, so a world point has no coordinate" }];
        completionHandler(kCLLocationCoordinate2DInvalid, 0, error);
    });
}

#pragma mark - Raycasting

- (NSArray<ARRaycastResult *> *)raycast:(ARRaycastQuery *)query
{
    NSMutableArray<ARRaycastResult *> *results = [NSMutableArray array];
    [self raycastWithQuery:query results:results];
    return results;
}

- (ARTrackedRaycast *)trackedRaycast:(ARRaycastQuery *)query
                       updateHandler:(void (^)(NSArray<ARRaycastResult *> *))updateHandler
{
    if (!updateHandler)
        return nil;
    // A tracked raycast is a ray the session keeps casting, frame after frame, and the handler is
    // called each time with what it hit. It stops when the caller says so or when the camera has
    // moved further than its own ray length, which is Apple's rule and the tracker's own check.
    __block ARTrackedRaycast *tracked = nil;
    tracked = [[ARTrackedRaycast alloc] initWithQuery:query];
    [self registerTrackedRaycast:tracked updateHandler:updateHandler];
    return tracked;
}

- (void)updateWithCollaborationData:(ARCollaborationData *)collaborationData
{
    // Collaboration data is what another participant's session sends over a shared world, and it
    // carries their anchors and their features. This is one session on one device: there is no
    // other participant to receive any, so there is nothing to apply and nothing is invented.
    (void)collaborationData;
}

- (void)captureHighResolutionFrameWithCompletion:(void (^)(ARFrame *, NSError *))completion
{
    if (!completion)
        return;
    dispatch_queue_t queue = _delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        NSError *error = nil;
        CVPixelBufferRef image = [_tracker copyHighResolutionImageWithError:&error];
        if (!image) {
            completion(nil, error);
            return;
        }
        // The picture is the same moment's picture, so the frame is the session's own frame carrying
        // it: the same pose, the same anchors, the same light, at the still output's resolution.
        ARFrame *frame = [self frameWithPixelBuffer:image];
        CVPixelBufferRelease(image);
        completion(frame, nil);
    });
}

@end
