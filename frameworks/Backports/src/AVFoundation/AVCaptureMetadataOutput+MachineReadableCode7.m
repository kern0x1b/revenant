#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import "RevenantAVMetadataConstruction.h"
#import "RevenantQRCode.h"

@interface RevenantQRMetadataFrames : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) AVCaptureMetadataOutput *output;
@property (nonatomic, assign) BOOL reported;
@end

@interface RevenantQRMetadataState : NSObject
@property (nonatomic, copy) NSArray *types;
@property (nonatomic, weak) AVCaptureSession *session;
@property (nonatomic, weak) AVCaptureSession *videoSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *video;
@property (nonatomic, strong) RevenantQRMetadataFrames *frames;
@end

@implementation RevenantQRMetadataFrames

@synthesize output = _output;
@synthesize reported = _reported;

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    AVCaptureMetadataOutput *output = self.output;
    CVImageBufferRef image = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!output || !image)
        return;
    CVPixelBufferLockBaseAddress(image, kCVPixelBufferLock_ReadOnly);
    const uint8_t *luma = CVPixelBufferGetBaseAddressOfPlane(image, 0);
    int width = (int)CVPixelBufferGetWidthOfPlane(image, 0);
    int height = (int)CVPixelBufferGetHeightOfPlane(image, 0);
    int stride = (int)CVPixelBufferGetBytesPerRowOfPlane(image, 0);
    CGRect rect = output.rectOfInterest;
    RevenantQRResult results[REVENANT_QR_MAX_RESULTS];
    int found = revenant_qr_decode_region(luma, width, height, stride, (float)rect.origin.x, (float)rect.origin.y,
                                          (float)rect.size.width, (float)rect.size.height, results, REVENANT_QR_MAX_RESULTS);
    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:found];
    for (int index = 0; index < found; index++) {
        NSString *text = [[NSString alloc] initWithBytes:results[index].text length:results[index].length encoding:NSUTF8StringEncoding];
        NSMutableArray *corners = [NSMutableArray arrayWithCapacity:4];
        for (int corner = 0; corner < 4; corner++) {
            CGPoint point = CGPointMake((CGFloat)results[index].corners[corner][0] / width, (CGFloat)results[index].corners[corner][1] / height);
            [corners addObject:CFBridgingRelease(CGPointCreateDictionaryRepresentation(point))];
        }
        if (text)
            [objects addObject:[[AVMetadataMachineReadableCodeObject alloc] revenant_initWithType:AVMetadataObjectTypeQRCode stringValue:text corners:corners time:time]];
        revenant_qr_result_free(&results[index]);
    }
    CVPixelBufferUnlockBaseAddress(image, kCVPixelBufferLock_ReadOnly);
    if (!objects.count && !self.reported)
        return;
    self.reported = objects.count > 0;
    id<AVCaptureMetadataOutputObjectsDelegate> target = output.metadataObjectsDelegate;
    dispatch_queue_t queue = output.metadataObjectsCallbackQueue;
    if (!queue || ![target respondsToSelector:@selector(captureOutput:didOutputMetadataObjects:fromConnection:)])
        return;
    dispatch_async(queue, ^{
        [target captureOutput:output didOutputMetadataObjects:objects fromConnection:connection];
    });
}

@end

@implementation RevenantQRMetadataState

@synthesize types = _types;
@synthesize session = _session;
@synthesize videoSession = _videoSession;
@synthesize video = _video;
@synthesize frames = _frames;

@end

static const char RevenantQRMetadataStateKey;

static IMP qr_native_available_types;
static IMP qr_native_metadata_types;
static IMP qr_native_set_metadata_types;
static IMP qr_native_set_metadata_delegate;
static IMP qr_native_add_output;
static IMP qr_native_remove_output;

static RevenantQRMetadataState *revenant_qr_state(AVCaptureMetadataOutput *output)
{
    RevenantQRMetadataState *state = objc_getAssociatedObject(output, &RevenantQRMetadataStateKey);
    if (!state) {
        state = [[RevenantQRMetadataState alloc] init];
        objc_setAssociatedObject(output, &RevenantQRMetadataStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

static BOOL revenant_qr_native_supports(AVCaptureMetadataOutput *output)
{
    NSArray *types = ((NSArray *(*)(id, SEL))qr_native_available_types)(output, @selector(availableMetadataObjectTypes));
    return [types containsObject:AVMetadataObjectTypeQRCode];
}

static OSType revenant_qr_pixel_format(AVCaptureVideoDataOutput *video)
{
    if ([video.availableVideoCVPixelFormatTypes containsObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)])
        return kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
}

static void revenant_qr_start(AVCaptureMetadataOutput *output, RevenantQRMetadataState *state)
{
    AVCaptureSession *session = state.session;
    AVCaptureVideoDataOutput *video = [[AVCaptureVideoDataOutput alloc] init];
    video.alwaysDiscardsLateVideoFrames = YES;
    video.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(revenant_qr_pixel_format(video))};
    RevenantQRMetadataFrames *frames = [[RevenantQRMetadataFrames alloc] init];
    frames.output = output;
    [video setSampleBufferDelegate:frames queue:dispatch_queue_create("org.revenant.qr-metadata", DISPATCH_QUEUE_SERIAL)];
    [session beginConfiguration];
    if ([session canAddOutput:video]) {
        [session addOutput:video];
        state.video = video;
        state.frames = frames;
        state.videoSession = session;
    } else
        NSLog(@"revenant: the session refused the video data output that reads QR codes for the metadata output");
    [session commitConfiguration];
}

static void revenant_qr_stop(RevenantQRMetadataState *state)
{
    AVCaptureSession *session = state.videoSession;
    AVCaptureVideoDataOutput *video = state.video;
    [session beginConfiguration];
    [session removeOutput:video];
    [session commitConfiguration];
    [video setSampleBufferDelegate:nil queue:NULL];
    state.video = nil;
    state.frames = nil;
    state.videoSession = nil;
}

static void revenant_qr_reconcile(AVCaptureMetadataOutput *output)
{
    RevenantQRMetadataState *state = revenant_qr_state(output);
    BOOL wanted = [state.types containsObject:AVMetadataObjectTypeQRCode] && state.session && [output metadataObjectsDelegate]
        && !revenant_qr_native_supports(output);
    if (wanted && !state.video)
        revenant_qr_start(output, state);
    else if (!wanted && state.video)
        revenant_qr_stop(state);
}

static NSArray *revenant_qr_available_types(AVCaptureMetadataOutput *self, SEL _cmd)
{
    NSArray *types = ((NSArray *(*)(id, SEL))qr_native_available_types)(self, _cmd);
    if ([types containsObject:AVMetadataObjectTypeQRCode])
        return types;
    return [(types ?: @[]) arrayByAddingObject:AVMetadataObjectTypeQRCode];
}

static NSArray *revenant_qr_metadata_types(AVCaptureMetadataOutput *self, SEL _cmd)
{
    RevenantQRMetadataState *state = objc_getAssociatedObject(self, &RevenantQRMetadataStateKey);
    if (state.types)
        return state.types;
    return ((NSArray *(*)(id, SEL))qr_native_metadata_types)(self, _cmd);
}

static void revenant_qr_set_metadata_types(AVCaptureMetadataOutput *self, SEL _cmd, NSArray *types)
{
    RevenantQRMetadataState *state = revenant_qr_state(self);
    state.types = types;
    BOOL native = revenant_qr_native_supports(self);
    NSMutableArray *nativeTypes = [NSMutableArray array];
    for (NSString *type in types)
        if (native || ![type isEqualToString:AVMetadataObjectTypeQRCode])
            [nativeTypes addObject:type];
    ((void (*)(id, SEL, NSArray *))qr_native_set_metadata_types)(self, _cmd, nativeTypes);
    revenant_qr_reconcile(self);
}

static void revenant_qr_set_metadata_delegate(AVCaptureMetadataOutput *self, SEL _cmd, id delegate, dispatch_queue_t queue)
{
    ((void (*)(id, SEL, id, dispatch_queue_t))qr_native_set_metadata_delegate)(self, _cmd, delegate, queue);
    revenant_qr_reconcile(self);
}

static void revenant_qr_add_output(AVCaptureSession *self, SEL _cmd, AVCaptureOutput *output)
{
    ((void (*)(id, SEL, AVCaptureOutput *))qr_native_add_output)(self, _cmd, output);
    if ([output isKindOfClass:[AVCaptureMetadataOutput class]]) {
        AVCaptureMetadataOutput *metadata = (AVCaptureMetadataOutput *)output;
        revenant_qr_state(metadata).session = self;
        revenant_qr_reconcile(metadata);
    }
}

static void revenant_qr_remove_output(AVCaptureSession *self, SEL _cmd, AVCaptureOutput *output)
{
    ((void (*)(id, SEL, AVCaptureOutput *))qr_native_remove_output)(self, _cmd, output);
    if ([output isKindOfClass:[AVCaptureMetadataOutput class]]) {
        AVCaptureMetadataOutput *metadata = (AVCaptureMetadataOutput *)output;
        RevenantQRMetadataState *state = revenant_qr_state(metadata);
        if (state.session == self) {
            state.session = nil;
            revenant_qr_reconcile(metadata);
        }
    }
}

static IMP revenant_qr_swizzle(Class cls, SEL selector, IMP replacement)
{
    Method method = class_getInstanceMethod(cls, selector);
    IMP original = method_getImplementation(method);
    method_setImplementation(method, replacement);
    return original;
}

@interface RevenantQRMetadataInstall : NSObject
@end

@implementation RevenantQRMetadataInstall

+ (void)load
{
    Class output = [AVCaptureMetadataOutput class];
    qr_native_available_types = revenant_qr_swizzle(output, @selector(availableMetadataObjectTypes), (IMP)revenant_qr_available_types);
    qr_native_metadata_types = revenant_qr_swizzle(output, @selector(metadataObjectTypes), (IMP)revenant_qr_metadata_types);
    qr_native_set_metadata_types = revenant_qr_swizzle(output, @selector(setMetadataObjectTypes:), (IMP)revenant_qr_set_metadata_types);
    qr_native_set_metadata_delegate = revenant_qr_swizzle(output, @selector(setMetadataObjectsDelegate:queue:), (IMP)revenant_qr_set_metadata_delegate);
    Class session = [AVCaptureSession class];
    qr_native_add_output = revenant_qr_swizzle(session, @selector(addOutput:), (IMP)revenant_qr_add_output);
    qr_native_remove_output = revenant_qr_swizzle(session, @selector(removeOutput:), (IMP)revenant_qr_remove_output);
}

@end
