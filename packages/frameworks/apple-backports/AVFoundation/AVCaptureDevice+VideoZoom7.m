#import "RevenantAVCapture.h"
#import <Accelerate/Accelerate.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface AVCaptureDevice (RevenantReleaseLock)
- (BOOL)isLockedForConfiguration;
@end

static const char revenant_zoom_key;
static const char revenant_ramp_key;

static NSString *const RevenantZoomRangeReason = @"videoZoomFactor out of range";
static NSString *const RevenantZoomLockReason = @"You must call lockForConfiguration and successfully obtain the configuration lock before modifying zoom factor";

@interface RevenantZoomRamp : NSObject
@property (nonatomic) CGFloat target;
@property (nonatomic) float rate;
@property (nonatomic) CFTimeInterval last;
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, weak) AVCaptureDevice *device;
- (void)step;
@end

static CGFloat revenant_zoom_of(AVCaptureDevice *device)
{
    NSNumber *stored = device ? objc_getAssociatedObject(device, &revenant_zoom_key) : nil;
    return stored ? (CGFloat)stored.doubleValue : 1;
}

static AVCaptureDevice *revenant_video_device_of(AVCaptureConnection *connection)
{
    for (AVCaptureInputPort *port in connection.inputPorts) {
        if ([port.mediaType isEqualToString:AVMediaTypeVideo] && [port.input isKindOfClass:[AVCaptureDeviceInput class]])
            return ((AVCaptureDeviceInput *)port.input).device;
    }
    return nil;
}

static AVCaptureDevice *revenant_video_device_of_session(AVCaptureSession *session)
{
    for (AVCaptureInput *input in session.inputs) {
        if ([input isKindOfClass:[AVCaptureDeviceInput class]] && [((AVCaptureDeviceInput *)input).device hasMediaType:AVMediaTypeVideo])
            return ((AVCaptureDeviceInput *)input).device;
    }
    return nil;
}

static void revenant_apply_zoom_to_session(AVCaptureSession *session)
{
    for (AVCaptureOutput *output in session.outputs) {
        for (AVCaptureConnection *connection in output.connections) {
            AVCaptureDevice *device = revenant_video_device_of(connection);
            if (device && connection.videoMaxScaleAndCropFactor > 1)
                connection.videoScaleAndCropFactor = (CGFloat)MIN(revenant_zoom_of(device), connection.videoMaxScaleAndCropFactor);
        }
    }
    CGFloat factor = revenant_zoom_of(revenant_video_device_of_session(session));
    NSArray *layers = [session revenant_previewLayers];
    void (^transform)(void) = ^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        for (AVCaptureVideoPreviewLayer *layer in layers)
            layer.sublayerTransform = CATransform3DMakeScale(factor, factor, 1);
        [CATransaction commit];
    };
    if ([NSThread isMainThread])
        transform();
    else
        dispatch_async(dispatch_get_main_queue(), transform);
}

static void revenant_apply_zoom(AVCaptureDevice *device)
{
    for (AVCaptureSession *session in [device revenant_captureSessions])
        revenant_apply_zoom_to_session(session);
}

static void revenant_store_zoom(AVCaptureDevice *device, CGFloat factor)
{
    [device willChangeValueForKey:@"videoZoomFactor"];
    objc_setAssociatedObject(device, &revenant_zoom_key, @(factor), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [device didChangeValueForKey:@"videoZoomFactor"];
    revenant_apply_zoom(device);
}

static void revenant_check_zoom(AVCaptureDevice *device, CGFloat factor)
{
    CGFloat maximum = device.activeFormat ? device.activeFormat.videoMaxZoomFactor : 1;
    if (!(factor >= 1) || factor > maximum)
        @throw [NSException exceptionWithName:NSRangeException reason:RevenantZoomRangeReason userInfo:nil];
    if (![device isLockedForConfiguration])
        @throw [NSException exceptionWithName:NSGenericException reason:RevenantZoomLockReason userInfo:nil];
}

static void revenant_end_ramp(AVCaptureDevice *device)
{
    RevenantZoomRamp *ramp = objc_getAssociatedObject(device, &revenant_ramp_key);
    if (!ramp)
        return;
    dispatch_source_cancel(ramp.timer);
    [device willChangeValueForKey:@"rampingVideoZoom"];
    objc_setAssociatedObject(device, &revenant_ramp_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [device didChangeValueForKey:@"rampingVideoZoom"];
}

@implementation RevenantZoomRamp

@synthesize target = _target, rate = _rate, last = _last, timer = _timer, device = _device;

- (void)step
{
    AVCaptureDevice *device = self.device;
    if (!device) {
        dispatch_source_cancel(self.timer);
        return;
    }
    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval elapsed = now - self.last;
    self.last = now;
    CGFloat current = revenant_zoom_of(device), target = self.target;
    CGFloat step = (CGFloat)pow(2.0, fabs(self.rate) * elapsed);
    CGFloat next = target > current ? MIN(target, current * step) : MAX(target, current / step);
    revenant_store_zoom(device, next);
    if (next == target)
        revenant_end_ramp(device);
}

@end

@implementation AVCaptureDevice (RevenantVideoZoom)

- (CGFloat)videoZoomFactor
{
    return revenant_zoom_of(self);
}

- (void)setVideoZoomFactor:(CGFloat)videoZoomFactor
{
    revenant_check_zoom(self, videoZoomFactor);
    revenant_end_ramp(self);
    revenant_store_zoom(self, videoZoomFactor);
}

- (void)rampToVideoZoomFactor:(CGFloat)factor withRate:(float)rate
{
    revenant_check_zoom(self, factor);
    if (rate == 0) {
        revenant_end_ramp(self);
        return;
    }
    RevenantZoomRamp *ramp = objc_getAssociatedObject(self, &revenant_ramp_key);
    if (!ramp) {
        ramp = [[RevenantZoomRamp alloc] init];
        ramp.device = self;
        ramp.last = CACurrentMediaTime();
        ramp.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(ramp.timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 60), NSEC_PER_SEC / 60, NSEC_PER_SEC / 240);
        __weak RevenantZoomRamp *weakRamp = ramp;
        dispatch_source_set_event_handler(ramp.timer, ^{
            [weakRamp step];
        });
        [self willChangeValueForKey:@"rampingVideoZoom"];
        objc_setAssociatedObject(self, &revenant_ramp_key, ramp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self didChangeValueForKey:@"rampingVideoZoom"];
        dispatch_resume(ramp.timer);
    }
    ramp.target = factor;
    ramp.rate = rate;
}

- (BOOL)isRampingVideoZoom
{
    return objc_getAssociatedObject(self, &revenant_ramp_key) != nil;
}

- (void)cancelVideoZoomRamp
{
    if (![self isLockedForConfiguration])
        @throw [NSException exceptionWithName:NSGenericException reason:RevenantZoomLockReason userInfo:nil];
    revenant_end_ramp(self);
}

@end

@implementation AVCaptureDeviceFormat (RevenantVideoZoom)

- (CGFloat)videoMaxZoomFactor
{
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(self.formatDescription);
    return MAX((CGFloat)1, (CGFloat)MIN(size.width, size.height) * (CGFloat)0.0625);
}

- (CGFloat)videoZoomFactorUpscaleThreshold
{
    return 1;
}

@end

#pragma mark - Video data output

static BOOL revenant_crop_plane(vImage_Buffer source, vImage_Buffer destination, CGFloat factor, size_t bytesPerPixel)
{
    size_t width = (size_t)MAX(1.0, round(source.width / factor)), height = (size_t)MAX(1.0, round(source.height / factor));
    size_t left = (source.width - width) / 2, top = (source.height - height) / 2;
    vImage_Buffer crop = {(uint8_t *)source.data + top * source.rowBytes + left * bytesPerPixel, height, width, source.rowBytes};
    vImage_Error error;
    if (bytesPerPixel == 4) {
        error = vImageScale_ARGB8888(&crop, &destination, NULL, kvImageHighQualityResampling);
    } else if (bytesPerPixel == 1) {
        error = vImageScale_Planar8(&crop, &destination, NULL, kvImageHighQualityResampling);
    } else {
        vImage_Buffer cb = {malloc(crop.width * crop.height), crop.height, crop.width, crop.width};
        vImage_Buffer cr = {malloc(crop.width * crop.height), crop.height, crop.width, crop.width};
        vImage_Buffer cbOut = {malloc(destination.width * destination.height), destination.height, destination.width, destination.width};
        vImage_Buffer crOut = {malloc(destination.width * destination.height), destination.height, destination.width, destination.width};
        error = cb.data && cr.data && cbOut.data && crOut.data ? kvImageNoError : kvImageMemoryAllocationError;
        if (error == kvImageNoError) {
            const void *chunky[2] = {crop.data, (uint8_t *)crop.data + 1};
            const vImage_Buffer *split[2] = {&cb, &cr};
            error = vImageConvert_ChunkyToPlanar8(chunky, split, 2, 2, crop.width, crop.height, crop.rowBytes, kvImageNoFlags);
        }
        if (error == kvImageNoError)
            error = vImageScale_Planar8(&cb, &cbOut, NULL, kvImageHighQualityResampling);
        if (error == kvImageNoError)
            error = vImageScale_Planar8(&cr, &crOut, NULL, kvImageHighQualityResampling);
        if (error == kvImageNoError) {
            const vImage_Buffer *joined[2] = {&cbOut, &crOut};
            void *out[2] = {destination.data, (uint8_t *)destination.data + 1};
            error = vImageConvert_PlanarToChunky8(joined, out, 2, 2, destination.width, destination.height, destination.rowBytes, kvImageNoFlags);
        }
        free(cb.data);
        free(cr.data);
        free(cbOut.data);
        free(crOut.data);
    }
    return error == kvImageNoError;
}

static CVPixelBufferRef revenant_create_cropped(CVPixelBufferRef source, CGFloat factor)
{
    OSType format = CVPixelBufferGetPixelFormatType(source);
    BOOL planar = format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    if (format != kCVPixelFormatType_32BGRA && !planar)
        return NULL;
    CVPixelBufferRef destination = NULL;
    NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    if (CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(source), CVPixelBufferGetHeight(source), format,
                            (__bridge CFDictionaryRef)attributes, &destination) != kCVReturnSuccess)
        return NULL;
    CVPixelBufferLockBaseAddress(source, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(destination, 0);
    BOOL cropped = YES;
    size_t planes = planar ? 2 : 1;
    for (size_t plane = 0; plane < planes && cropped; plane++) {
        vImage_Buffer in, out;
        if (planar) {
            in = (vImage_Buffer){CVPixelBufferGetBaseAddressOfPlane(source, plane), CVPixelBufferGetHeightOfPlane(source, plane),
                                 CVPixelBufferGetWidthOfPlane(source, plane), CVPixelBufferGetBytesPerRowOfPlane(source, plane)};
            out = (vImage_Buffer){CVPixelBufferGetBaseAddressOfPlane(destination, plane), CVPixelBufferGetHeightOfPlane(destination, plane),
                                  CVPixelBufferGetWidthOfPlane(destination, plane), CVPixelBufferGetBytesPerRowOfPlane(destination, plane)};
        } else {
            in = (vImage_Buffer){CVPixelBufferGetBaseAddress(source), CVPixelBufferGetHeight(source), CVPixelBufferGetWidth(source), CVPixelBufferGetBytesPerRow(source)};
            out = (vImage_Buffer){CVPixelBufferGetBaseAddress(destination), CVPixelBufferGetHeight(destination), CVPixelBufferGetWidth(destination),
                                  CVPixelBufferGetBytesPerRow(destination)};
        }
        cropped = revenant_crop_plane(in, out, factor, planar ? (plane == 0 ? 1 : 2) : 4);
    }
    CVPixelBufferUnlockBaseAddress(destination, 0);
    CVPixelBufferUnlockBaseAddress(source, kCVPixelBufferLock_ReadOnly);
    if (!cropped) {
        CVPixelBufferRelease(destination);
        return NULL;
    }
    CVBufferPropagateAttachments(source, destination);
    return destination;
}

CMSampleBufferRef revenant_create_zoomed_sample(CMSampleBufferRef sample, CGFloat factor);

CMSampleBufferRef revenant_create_zoomed_sample(CMSampleBufferRef sample, CGFloat factor)
{
    CVImageBufferRef source = CMSampleBufferGetImageBuffer(sample);
    CVPixelBufferRef pixels = source ? revenant_create_cropped(source, factor) : NULL;
    if (!pixels)
        return NULL;
    CMSampleTimingInfo timing;
    CMVideoFormatDescriptionRef description = NULL;
    CMSampleBufferRef zoomed = NULL;
    if (CMSampleBufferGetSampleTimingInfo(sample, 0, &timing) == noErr
        && CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixels, &description) == noErr
        && CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixels, true, NULL, NULL, description, &timing, &zoomed) == noErr)
        CMPropagateAttachments(sample, zoomed);
    if (description)
        CFRelease(description);
    CVPixelBufferRelease(pixels);
    return zoomed;
}

@interface RevenantZoomSampleRelay : NSProxy <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate;
@property (atomic) BOOL refusalLogged;
@end

@implementation RevenantZoomSampleRelay

@synthesize delegate = _delegate, refusalLogged = _refusalLogged;

- (instancetype)initWithDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate
{
    _delegate = delegate;
    return self;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate = self.delegate;
    if (![delegate respondsToSelector:_cmd])
        return;
    CGFloat factor = revenant_zoom_of(revenant_video_device_of(connection));
    CMSampleBufferRef zoomed = factor > 1 ? revenant_create_zoomed_sample(sampleBuffer, factor) : NULL;
    if (factor > 1 && !zoomed && !self.refusalLogged) {
        self.refusalLogged = YES;
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        FourCharCode type = format ? CMFormatDescriptionGetMediaSubType(format) : 0;
        NSLog(@"AVCaptureDevice videoZoomFactor: a video data output buffer of format '%c%c%c%c' could not be cropped; it is delivered whole",
              (char)(type >> 24), (char)(type >> 16), (char)(type >> 8), (char)type);
    }
    [delegate captureOutput:output didOutputSampleBuffer:zoomed ?: sampleBuffer fromConnection:connection];
    if (zoomed)
        CFRelease(zoomed);
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [self.delegate respondsToSelector:selector];
}

- (BOOL)conformsToProtocol:(Protocol *)protocol
{
    return [self.delegate conformsToProtocol:protocol];
}

- (Class)class
{
    return [(NSObject *)self.delegate class];
}

- (BOOL)isKindOfClass:(Class)kind
{
    return [(NSObject *)self.delegate isKindOfClass:kind];
}

- (BOOL)isMemberOfClass:(Class)kind
{
    return [(NSObject *)self.delegate isMemberOfClass:kind];
}

- (BOOL)isEqual:(id)object
{
    return [(NSObject *)self.delegate isEqual:object];
}

- (NSUInteger)hash
{
    return [(NSObject *)self.delegate hash];
}

- (NSString *)description
{
    return [(NSObject *)self.delegate description];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [(NSObject *)self.delegate methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    [invocation invokeWithTarget:self.delegate];
}

@end

static const char revenant_relay_key;

@interface RevenantVideoZoomInstaller : NSObject
@end

@implementation RevenantVideoZoomInstaller

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:REVENANT_CAPTURE_SESSION_CHANGED object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_apply_zoom_to_session(note.object);
    }];

    Class data = [AVCaptureVideoDataOutput class];
    SEL setDelegate = @selector(setSampleBufferDelegate:queue:);
    Method setMethod = class_getInstanceMethod(data, setDelegate);
    IMP originalSet = method_getImplementation(setMethod);
    method_setImplementation(setMethod, imp_implementationWithBlock(^(AVCaptureVideoDataOutput *self, id delegate, dispatch_queue_t queue) {
        RevenantZoomSampleRelay *relay = delegate ? [[RevenantZoomSampleRelay alloc] initWithDelegate:delegate] : nil;
        objc_setAssociatedObject(self, &revenant_relay_key, relay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ((void (*)(id, SEL, id, dispatch_queue_t))originalSet)(self, setDelegate, relay, queue);
    }));

    Class preview = [AVCaptureVideoPreviewLayer class];
    SEL toDevice = @selector(captureDevicePointOfInterestForPoint:);
    Method toDeviceMethod = class_getInstanceMethod(preview, toDevice);
    IMP originalToDevice = method_getImplementation(toDeviceMethod);
    method_setImplementation(toDeviceMethod, imp_implementationWithBlock(^CGPoint(AVCaptureVideoPreviewLayer *self, CGPoint point) {
        CGFloat factor = revenant_zoom_of(revenant_video_device_of_session(self.session));
        CGPoint centre = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        CGPoint unzoomed = CGPointMake(centre.x + (point.x - centre.x) / factor, centre.y + (point.y - centre.y) / factor);
        return ((CGPoint (*)(id, SEL, CGPoint))originalToDevice)(self, toDevice, unzoomed);
    }));
    SEL toLayer = @selector(pointForCaptureDevicePointOfInterest:);
    Method toLayerMethod = class_getInstanceMethod(preview, toLayer);
    IMP originalToLayer = method_getImplementation(toLayerMethod);
    method_setImplementation(toLayerMethod, imp_implementationWithBlock(^CGPoint(AVCaptureVideoPreviewLayer *self, CGPoint point) {
        CGFloat factor = revenant_zoom_of(revenant_video_device_of_session(self.session));
        CGPoint centre = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        CGPoint unzoomed = ((CGPoint (*)(id, SEL, CGPoint))originalToLayer)(self, toLayer, point);
        return CGPointMake(centre.x + (unzoomed.x - centre.x) * factor, centre.y + (unzoomed.y - centre.y) * factor);
    }));
}

@end
