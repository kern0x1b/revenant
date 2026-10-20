#import "RevenantAVCapture.h"
#import <objc/runtime.h>

NSArray *revenant_capture_devices(NSArray *deviceTypes, NSString *mediaType, AVCaptureDevicePosition position)
{
    NSMutableArray *found = [NSMutableArray array];
    if ([deviceTypes containsObject:AVCaptureDeviceTypeBuiltInWideAngleCamera] || [deviceTypes containsObject:AVCaptureDeviceTypeBuiltInTelephotoCamera]
        || [deviceTypes containsObject:REVENANT_DUAL_CAMERA_TYPE])
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

static const char revenant_sessions_key;
static const char revenant_preview_layers_key;

static NSHashTable *revenant_weak_set(id owner, const void *key)
{
    NSHashTable *set = objc_getAssociatedObject(owner, key);
    if (!set) {
        set = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(owner, key, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}

static void revenant_session_changed(AVCaptureSession *session)
{
    if (session)
        [[NSNotificationCenter defaultCenter] postNotificationName:REVENANT_CAPTURE_SESSION_CHANGED object:session];
}

@implementation AVCaptureDevice (RevenantCaptureSessions)

- (NSArray<AVCaptureSession *> *)revenant_captureSessions
{
    NSHashTable *sessions = revenant_weak_set(self, &revenant_sessions_key);
    @synchronized (sessions) {
        return sessions.allObjects;
    }
}

@end

@implementation AVCaptureSession (RevenantCaptureSessions)

- (NSArray<AVCaptureVideoPreviewLayer *> *)revenant_previewLayers
{
    NSHashTable *layers = revenant_weak_set(self, &revenant_preview_layers_key);
    @synchronized (layers) {
        return layers.allObjects;
    }
}

@end

static void revenant_wrap_session(SEL selector)
{
    Method method = class_getInstanceMethod([AVCaptureSession class], selector);
    IMP original = method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^(AVCaptureSession *self) {
        ((void (*)(AVCaptureSession *, SEL))original)(self, selector);
        revenant_session_changed(self);
    }));
}

@interface RevenantCaptureSessionsInstaller : NSObject
@end

@implementation RevenantCaptureSessionsInstaller

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionDidStartRunningNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_session_changed(note.object);
    }];
    revenant_wrap_session(@selector(commitConfiguration));

    SEL addOutput = @selector(addOutput:);
    Method outputMethod = class_getInstanceMethod([AVCaptureSession class], addOutput);
    IMP originalAddOutput = method_getImplementation(outputMethod);
    method_setImplementation(outputMethod, imp_implementationWithBlock(^(AVCaptureSession *self, AVCaptureOutput *output) {
        ((void (*)(AVCaptureSession *, SEL, AVCaptureOutput *))originalAddOutput)(self, addOutput, output);
        revenant_session_changed(self);
    }));

    SEL addInput = @selector(addInput:);
    Method inputMethod = class_getInstanceMethod([AVCaptureSession class], addInput);
    IMP originalAddInput = method_getImplementation(inputMethod);
    method_setImplementation(inputMethod, imp_implementationWithBlock(^(AVCaptureSession *self, AVCaptureInput *input) {
        ((void (*)(AVCaptureSession *, SEL, AVCaptureInput *))originalAddInput)(self, addInput, input);
        if ([input isKindOfClass:[AVCaptureDeviceInput class]]) {
            NSHashTable *sessions = revenant_weak_set(((AVCaptureDeviceInput *)input).device, &revenant_sessions_key);
            @synchronized (sessions) {
                [sessions addObject:self];
            }
        }
        revenant_session_changed(self);
    }));

    SEL setSession = @selector(setSession:);
    Method layerMethod = class_getInstanceMethod([AVCaptureVideoPreviewLayer class], setSession);
    IMP originalSetSession = method_getImplementation(layerMethod);
    method_setImplementation(layerMethod, imp_implementationWithBlock(^(AVCaptureVideoPreviewLayer *self, AVCaptureSession *session) {
        ((void (*)(AVCaptureVideoPreviewLayer *, SEL, AVCaptureSession *))originalSetSession)(self, setSession, session);
        if (session) {
            NSHashTable *layers = revenant_weak_set(session, &revenant_preview_layers_key);
            @synchronized (layers) {
                [layers addObject:self];
            }
        }
        revenant_session_changed(session);
    }));
}

@end
