#import "CharonAVCapture.h"
#import <objc/runtime.h>

NSArray *charon_capture_devices(NSArray *deviceTypes, NSString *mediaType, AVCaptureDevicePosition position)
{
    NSMutableArray *found = [NSMutableArray array];
    if ([deviceTypes containsObject:AVCaptureDeviceTypeBuiltInWideAngleCamera] || [deviceTypes containsObject:AVCaptureDeviceTypeBuiltInTelephotoCamera]
        || [deviceTypes containsObject:CHARON_DUAL_CAMERA_TYPE])
        [found addObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]];
    if ([deviceTypes containsObject:AVCaptureDeviceTypeBuiltInMicrophone])
        [found addObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio]];
    NSMutableArray *matching = [NSMutableArray array];
    for (AVCaptureDevice *device in found) {
        if (device.connected && (position == AVCaptureDevicePositionUnspecified || device.position == position)
            && (!mediaType || [device hasMediaType:mediaType]) && [deviceTypes containsObject:[device deviceType]])
            [matching addObject:device];
    }
    return [matching sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(AVCaptureDevice *first, AVCaptureDevice *second) {
        NSUInteger firstType = [deviceTypes indexOfObject:[first deviceType]], secondType = [deviceTypes indexOfObject:[second deviceType]];
        if (firstType != secondType)
            return firstType < secondType ? NSOrderedAscending : NSOrderedDescending;
        if (first.position == second.position)
            return NSOrderedSame;
        return first.position < second.position ? NSOrderedAscending : NSOrderedDescending;
    }];
}

// Which sessions a device is in and which preview layers show a session: the release answers neither, and
// the backports that act on every connection of a device (the frame durations, the zoom) need both. Every
// change of a session is announced once, after the release has made it.
static const char charon_sessions_key;
static const char charon_preview_layers_key;

static NSHashTable *charon_weak_set(id owner, const void *key)
{
    NSHashTable *set = objc_getAssociatedObject(owner, key);
    if (!set) {
        set = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(owner, key, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}

static void charon_session_changed(AVCaptureSession *session)
{
    if (session)
        [[NSNotificationCenter defaultCenter] postNotificationName:CHARON_CAPTURE_SESSION_CHANGED object:session];
}

@implementation AVCaptureDevice (CharonCaptureSessions)

- (NSArray<AVCaptureSession *> *)charon_captureSessions
{
    NSHashTable *sessions = charon_weak_set(self, &charon_sessions_key);
    @synchronized (sessions) {
        return sessions.allObjects;
    }
}

@end

@implementation AVCaptureSession (CharonCaptureSessions)

- (NSArray<AVCaptureVideoPreviewLayer *> *)charon_previewLayers
{
    NSHashTable *layers = charon_weak_set(self, &charon_preview_layers_key);
    @synchronized (layers) {
        return layers.allObjects;
    }
}

@end

static void charon_wrap_session(SEL selector)
{
    Method method = class_getInstanceMethod([AVCaptureSession class], selector);
    IMP original = method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^(AVCaptureSession *self) {
        ((void (*)(AVCaptureSession *, SEL))original)(self, selector);
        charon_session_changed(self);
    }));
}

@interface CharonCaptureSessionsInstaller : NSObject
@end

@implementation CharonCaptureSessionsInstaller

+ (void)load
{
    // A session that starts running says so publicly; a configuration committed, an input or an output added and a
    // preview layer given a session are said by nothing public of 6.x, and are taken from the release's own methods
    // (facts/AVFoundation/CaptureZoomAudioSession.md, "What is replaced, and why").
    [[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionDidStartRunningNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        charon_session_changed(note.object);
    }];
    charon_wrap_session(@selector(commitConfiguration));

    SEL addOutput = @selector(addOutput:);
    Method outputMethod = class_getInstanceMethod([AVCaptureSession class], addOutput);
    IMP originalAddOutput = method_getImplementation(outputMethod);
    method_setImplementation(outputMethod, imp_implementationWithBlock(^(AVCaptureSession *self, AVCaptureOutput *output) {
        ((void (*)(AVCaptureSession *, SEL, AVCaptureOutput *))originalAddOutput)(self, addOutput, output);
        charon_session_changed(self);
    }));

    SEL addInput = @selector(addInput:);
    Method inputMethod = class_getInstanceMethod([AVCaptureSession class], addInput);
    IMP originalAddInput = method_getImplementation(inputMethod);
    method_setImplementation(inputMethod, imp_implementationWithBlock(^(AVCaptureSession *self, AVCaptureInput *input) {
        ((void (*)(AVCaptureSession *, SEL, AVCaptureInput *))originalAddInput)(self, addInput, input);
        if ([input isKindOfClass:[AVCaptureDeviceInput class]]) {
            NSHashTable *sessions = charon_weak_set(((AVCaptureDeviceInput *)input).device, &charon_sessions_key);
            @synchronized (sessions) {
                [sessions addObject:self];
            }
        }
        charon_session_changed(self);
    }));

    // -initWithSession: gives the layer its session through -setSession: as well.
    SEL setSession = @selector(setSession:);
    Method layerMethod = class_getInstanceMethod([AVCaptureVideoPreviewLayer class], setSession);
    IMP originalSetSession = method_getImplementation(layerMethod);
    method_setImplementation(layerMethod, imp_implementationWithBlock(^(AVCaptureVideoPreviewLayer *self, AVCaptureSession *session) {
        ((void (*)(AVCaptureVideoPreviewLayer *, SEL, AVCaptureSession *))originalSetSession)(self, setSession, session);
        if (session) {
            NSHashTable *layers = charon_weak_set(session, &charon_preview_layers_key);
            @synchronized (layers) {
                [layers addObject:self];
            }
        }
        charon_session_changed(session);
    }));
}

@end
