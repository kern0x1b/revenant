#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>

#import "CharonARTracker.h"
#import "CharonARKitPrivate.h"

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

#pragma mark - Running

- (void)runWithConfiguration:(ARConfiguration *)configuration
{
    [self runWithConfiguration:configuration options:(ARSessionRunOptions)0];
}

- (void)runWithConfiguration:(ARConfiguration *)configuration options:(ARSessionRunOptions)options
{
    if (![[configuration class] isSupported]) {
        NSError *unsupported = [NSError errorWithDomain:ARErrorDomain
                                                   code:ARErrorCodeUnsupportedConfiguration
                                               userInfo:nil];
        if ([_delegate respondsToSelector:@selector(session:didFailWithError:)])
            [_delegate session:self didFailWithError:unsupported];
        return;
    }
    [_tracker stop];
    ARWorldMap *map = [configuration respondsToSelector:@selector(initialWorldMap)]
        ? [(id)configuration initialWorldMap] : nil;
    if (map.trackerState)
        [_tracker restoreWorldState:map.trackerState];
    NSError *error = nil;
    BOOL started = [configuration isKindOfClass:[AROrientationTrackingConfiguration class]]
        ? [_tracker startOrientationWithError:&error]
        : [_tracker startWithError:&error];
    if (!started) {
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
    if (map.anchors)
        [_anchors addObjectsFromArray:map.anchors];
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

    _currentFrame = frame;
    dispatch_queue_t queue = _delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        if ([self.delegate respondsToSelector:@selector(session:didUpdateFrame:)])
            [self.delegate session:self didUpdateFrame:frame];
        if ([self.delegate respondsToSelector:@selector(session:didAddAnchors:)])
            [self.delegate session:self didAddAnchors:added];
    });
}

- (NSArray<ARPlaneAnchor *> *)planeAnchorsForTracker:(CharonARTracker *)tracker
{
    NSMutableArray<ARPlaneAnchor *> *out = [NSMutableArray array];
    for (CharonARValue *value in tracker.planes) {
        [out addObject:[[ARPlaneAnchor alloc] initWithPlaneValue:value]];
    }
    return out;
}

- (NSArray<ARAnchor *> *)anchors
{
    NSMutableArray<ARAnchor *> *out = [NSMutableArray arrayWithCapacity:_anchors.count];
    for (ARAnchor *anchor in _anchors)
        [out addObject:[[anchor copyWithZone:NULL] anchorByApplyingOrigin:_worldOrigin]];
    [out addObjectsFromArray:[self planeAnchorsForTracker:_tracker]];
    return out;
}

- (void)reloadAnchorsFromTracker
{
    for (ARPlaneAnchor *plane in [self planeAnchorsForTracker:_tracker])
        [_pending addObject:plane];
}

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

- (void)registerTrackedRaycast:(ARTrackedRaycast *)tracked
                 updateHandler:(void (^)(NSArray<ARRaycastResult *> *))updateHandler
{
    [_trackedRaycasts addObject:@{ @"raycast": tracked, @"handler": [updateHandler copy] }];
}

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
            continue;
        }
        [survivors addObject:@{ @"raycast": tracked, @"handler": handler,
                                @"lastPosition": @[ @(eye.x), @(eye.y), @(eye.z) ] }];
    }
    _trackedRaycasts = survivors;
}

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
    [_tracker raycastFromOrigin:query.origin direction:query.direction
                         allowing:query.target results:hits];
    for (CharonARValue *value in hits)
        [results addObject:[[ARRaycastResult alloc] initWithHitValue:value]];
}

#pragma mark - The world

- (void)setWorldOrigin:(simd_float4x4)relativeTransform
{
    _worldOrigin = relativeTransform;
    [self reloadAnchorsFromTracker];
}

- (void)getCurrentWorldMapWithCompletionHandler:(void (^)(ARWorldMap *, NSError *))completionHandler
{
    if (!completionHandler)
        return;
    dispatch_queue_t queue = _delegateQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        ARPointCloud *points = [[ARPointCloud alloc] initWithPoints:_tracker.pointCloud
                                                             count:_tracker.pointCloud.length / sizeof(simd_float3)];
        ARWorldMap *map = [[ARWorldMap alloc] initWithAnchors:self.anchors featurePoints:points];
        map.trackerState = [_tracker worldState];
        completionHandler(map, nil);
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
    __block ARTrackedRaycast *tracked = nil;
    tracked = [[ARTrackedRaycast alloc] initWithQuery:query];
    [self registerTrackedRaycast:tracked updateHandler:updateHandler];
    return tracked;
}

- (void)updateWithCollaborationData:(ARCollaborationData *)collaborationData
{
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
        ARFrame *frame = [self frameWithPixelBuffer:image];
        CVPixelBufferRelease(image);
        completion(frame, nil);
    });
}

@end
