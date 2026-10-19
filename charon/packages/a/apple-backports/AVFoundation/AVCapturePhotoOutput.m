#import "CharonAVCapturePhoto.h"
#import <Accelerate/Accelerate.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <stdatomic.h>

// Ranks 16/17 of coordination/corpus/crash-demand-top.tsv, LOAD-FAIL, class_confirmed against
// both telegram and session's own trees. Two-step check first: apple.objc.inventory() against
// the armv7 shared cache of 6.1.3 confirms AVCapturePhotoOutput/AVCapturePhotoSettings/
// AVCaptureResolvedPhotoSettings do not exist under any name on this release - a genuine gap -
// while AVCaptureStillImageOutput, the class the header itself documents the new API as sitting
// above, is real, exported, and already a working AVCaptureOutput subclass on this release; grep
// of this tree's own .m files found no orphaned implementation already carrying a demanded
// selector. Ladder-walked with tools' own cache-by-cache inventory (not read from the SDK
// header's availability attribute, which names when Apple published the symbol, not when it
// first exports): all three classes first export at 10.0.1, not the header's bare "10.0".
//
// What Telegram's own delegate implementation resolved this design: the corpus's defcache for
// telegram defines *both*
// -captureOutput:didFinishProcessingPhoto:error: (the AVCapturePhoto-based, iOS 11+ callback) and
// -captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:
// (the original, iOS 10-era CMSampleBufferRef-based callback, deprecated in 13.0 but never
// removed) - the second is the one iOS 10 itself used before AVCapturePhoto existed, needs no
// AVCapturePhoto object, and is a real fallback path Telegram already ships for pre-11
// devices. This port targets exactly that path. The AVCapturePhoto callback is not implemented: it is not demanded
// yet, and it is work the port can do, as it builds previews, thumbnails and Exif itself (facts, "Open").
//
// On this release AVCapturePhotoOutput is an AVCaptureStillImageOutput itself, the one output class that captures
// stills, so the session builds and runs it as its own: 6.1.3's AVCaptureSession reads its own -outputs while it
// builds the graph at -startRunning and again while a capture runs, and an object standing beside the real output
// there (the first version of this port) made every capture end in AVFoundationErrorDomain -11800
// (facts/AVFoundation/AVCapturePhotoOutput.md, "Why the output is a still image output"). The SDK declares the
// class above AVCaptureOutput, so the implementation is declared under a name of its own and carries the class's
// name at run time.
__attribute__((objc_runtime_name("AVCapturePhotoOutput")))
@interface CharonPhotoOutput : AVCaptureStillImageOutput
@end

static AVCaptureDevice *CharonDeviceForConnection(AVCaptureConnection *connection)
{
    AVCaptureInputPort *port = connection.inputPorts.firstObject;
    AVCaptureInput *input = port.input;
    return [input isKindOfClass:[AVCaptureDeviceInput class]] ? ((AVCaptureDeviceInput *)input).device : nil;
}

// A flash mode onto the camera, where the release's still image output reads it: the one place this release keeps the
// flash mode a request asks for. A camera without a flash, or without that mode, is left as it is, and so is one that
// cannot be locked, which is logged. YES when the camera's mode was changed.
static BOOL CharonSetCameraFlashMode(AVCaptureDevice *device, AVCaptureFlashMode flashMode)
{
    if (!device.hasFlash || ![device isFlashModeSupported:flashMode] || device.flashMode == flashMode)
        return NO;
    NSError *error = nil;
    if (![device lockForConfiguration:&error]) {
        NSLog(@"AVCapturePhotoOutput: the camera could not be locked to set its flash mode to %ld; it stays %ld: %@", (long)flashMode,
              (long)device.flashMode, error);
        return NO;
    }
    device.flashMode = flashMode;
    [device unlockForConfiguration];
    return YES;
}

// flashActive, which says whether the flash would fire for a still image now (iOS 5), is the camera's judgement
// of the frames it delivers: after its flash mode changes it answers for the old mode until a frame is judged for the new
// one, which took 0.035 s on an iPhone 4S in the dark: a still captured after that change fired the flash in Auto, and one
// captured at once did not (facts, "The flash waits for the camera"). The wait runs `then` once: at flashActive's first change, or after `bound` seconds
// when it does not change, as in a bright scene with Auto, where it stays NO.
static char CharonFlashActiveContext;

__attribute__((visibility("hidden")))
@interface CharonFlashActiveWait : NSObject
@end

@implementation CharonFlashActiveWait
{
    id _camera;
    void (^_then)(void);
    atomic_flag _done;
}

- (void)finish
{
    if (atomic_flag_test_and_set(&_done))
        return;
    [_camera removeObserver:self forKeyPath:@"flashActive" context:&CharonFlashActiveContext];
    _then();
    _then = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &CharonFlashActiveContext)
        [self finish];
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

void CharonAfterFlashActiveChanges(id camera, NSTimeInterval bound, void (^then)(void))
{
    CharonFlashActiveWait *wait = [[CharonFlashActiveWait alloc] init];
    wait->_camera = camera;
    wait->_then = [then copy];
    [camera addObserver:wait forKeyPath:@"flashActive" options:0 context:&CharonFlashActiveContext];
    // The wait lives until the bound has passed, also when flashActive came first, so that a change notification already
    // on its way never reaches a released observer.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(bound * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [wait finish];
    });
}

@end

static void CharonOutputRaise(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void CharonOutputRaise(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
}

// What this output holds of its own. Every member the SDK 16.4 header declares answers explicitly: what the release's
// still image output can do is its answer, and what the port does not implement, or the 4S's one camera has no hardware
// for, answers the way the host's output answers with no camera behind it, each such feature NO and each setter that would turn one on raising
// NSInvalidArgumentException with the host's text (facts/AVFoundation/AVCapturePhotoOutput.md, "The photo output").
// The camera's exposure bias as 6.1.3 keeps it: the private getter of the pair AVFoundationDemand8.m drives (the setter is
// -setExposureTargetBias:completionHandler:'s), read to give the bias back after a bracket of auto exposures.
@interface AVCaptureDevice (CharonAutoExposureBias)
- (float)autoExposureBias;
@end

// The release's private manual exposure pair (AVFoundation's exposure duration and gain, measured on the 6.1.3 runtime:
// setExposureDuration: takes a CMTime, setExposureGain: a float; facts/AVFoundation/AVCapturePhotoBracketSettings.md, "Manual
// exposure"). 6.1.3 has no public manual exposure, and no ISO setter: the gain is the one the manual member's ISO goes to.
@interface AVCaptureDevice (CharonManualExposure)
- (CMTime)exposureDuration;
- (void)setExposureDuration:(CMTime)duration;
- (float)exposureGain;
- (void)setExposureGain:(float)gain;
@end

// The count of members the port's bracket path delivers, and the count its capture enforces (charon_checkBracket:, refused above).
// The bracket is a chain of stills: the next still is taken when the previous photo's callbacks have returned, and the port holds
// no sample buffer past its callback, so nothing in the chain bounds the count except this limit. It is the bracket the probe
// exercises (three members, tests/backports/emulate/photobracket). It is an implemented limit of the port, not a capacity of the
// 4S: no device is attached to measure one (facts/AVFoundation/AVCapturePhotoBracketSettings.md, "maxBracketedCapturePhotoCount").
static const NSUInteger CharonBracketedCapturePhotoLimit = 3;

@implementation CharonPhotoOutput
{
    BOOL _charonHighResolutionCaptureEnabled;
    AVCapturePhotoQualityPrioritization _charonMaxPhotoQualityPrioritization;
    AVCapturePhotoSettings *_charonPhotoSettingsForSceneMonitoring;
    NSArray *_charonPreparedPhotoSettingsArray;
    void (^_charonPrepareHandler)(BOOL, NSError *);
    id _charonPrepareObserver;
    CMVideoDimensions _charonMaxPhotoDimensions;
    NSMutableSet *_charonCapturedUniqueIDs;
    dispatch_queue_t _charonCaptureQueue;
    NSUInteger _charonCapturesInFlight;
    AVCaptureDevice *_charonFlashModeCamera;
    AVCaptureFlashMode _charonApplicationFlashMode;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _charonMaxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationBalanced;
        // "By default, [the output] prepares for +[AVCapturePhotoSettings photoSettings]" (the header).
        _charonPreparedPhotoSettingsArray = @[[AVCapturePhotoSettings photoSettings]];
        _charonCapturedUniqueIDs = [NSMutableSet set];
        _charonCaptureQueue = dispatch_queue_create("AVCapturePhotoOutput.capture", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc
{
    if (_charonPrepareObserver)
        [[NSNotificationCenter defaultCenter] removeObserver:_charonPrepareObserver];
}

// The output changes the camera's flash mode only while it needs it, where the host's output leaves the camera's own
// alone: the mode the application had is kept at the first change, and given back once no capture is running and no
// scene is monitored.
- (BOOL)charon_setFlashMode:(AVCaptureFlashMode)flashMode ofCamera:(AVCaptureDevice *)camera
{
    AVCaptureFlashMode before = camera.flashMode;
    if (!CharonSetCameraFlashMode(camera, flashMode))
        return NO;
    @synchronized (self) {
        if (!_charonFlashModeCamera) {
            _charonFlashModeCamera = camera;
            _charonApplicationFlashMode = before;
        }
    }
    return YES;
}

- (void)charon_giveBackCameraFlashMode
{
    AVCaptureDevice *camera;
    AVCaptureFlashMode flashMode;
    @synchronized (self) {
        if (!_charonFlashModeCamera || _charonCapturesInFlight || _charonPhotoSettingsForSceneMonitoring)
            return;
        camera = _charonFlashModeCamera;
        flashMode = _charonApplicationFlashMode;
        _charonFlashModeCamera = nil;
    }
    CharonSetCameraFlashMode(camera, flashMode);
}

- (AVCaptureConnection *)charon_videoConnection
{
    return [self connectionWithMediaType:AVMediaTypeVideo];
}

// "Empty until the receiver is added to an AVCaptureSession with a video source" (the header), then the release's own
// still image output's answer.
- (NSArray<NSNumber *> *)availablePhotoPixelFormatTypes
{
    return self.charon_videoConnection ? self.availableImageDataCVPixelFormatTypes ?: @[] : @[];
}

- (NSArray<AVVideoCodecType> *)availablePhotoCodecTypes
{
    return self.charon_videoConnection ? self.availableImageDataCodecTypes ?: @[] : @[];
}

// The file types a processed photo is written as: JPEG for the JPEG codec, TIFF for an uncompressed pixel format, as
// +photoSettings and the uncompressed formats resolve their processedFileType (the host).
- (NSArray<AVFileType> *)availablePhotoFileTypes
{
    NSMutableArray *types = [NSMutableArray array];
    if ([self.availablePhotoCodecTypes containsObject:AVVideoCodecTypeJPEG])
        [types addObject:AVFileTypeJPEG];
    if (self.availablePhotoPixelFormatTypes.count)
        [types addObject:AVFileTypeTIFF];
    return types;
}

- (NSArray<NSNumber *> *)supportedPhotoPixelFormatTypesForFileType:(AVFileType)fileType
{
    return [fileType isEqualToString:AVFileTypeTIFF] && [self.availablePhotoFileTypes containsObject:fileType] ? self.availablePhotoPixelFormatTypes : @[];
}

- (NSArray<AVVideoCodecType> *)supportedPhotoCodecTypesForFileType:(AVFileType)fileType
{
    return [fileType isEqualToString:AVFileTypeJPEG] && [self.availablePhotoFileTypes containsObject:fileType] ? @[AVVideoCodecTypeJPEG] : @[];
}

// RAW is not implemented: the release's still image output gives no Bayer or ProRAW sample to build on, and the port
// writes no DNG (facts, "Open").
- (NSArray<NSNumber *> *)availableRawPhotoPixelFormatTypes
{
    return @[];
}

- (NSArray<AVFileType> *)availableRawPhotoFileTypes
{
    return @[];
}

- (NSArray<NSNumber *> *)supportedRawPhotoPixelFormatTypesForFileType:(AVFileType)fileType
{
    return @[];
}

+ (BOOL)isBayerRAWPixelFormat:(OSType)pixelFormat
{
    return CharonIsBayerRAWPixelFormat(pixelFormat);
}

+ (BOOL)isAppleProRAWPixelFormat:(OSType)pixelFormat
{
    return CharonIsAppleProRAWPixelFormat(pixelFormat);
}

- (BOOL)isAppleProRAWSupported
{
    return NO;
}

- (BOOL)isAppleProRAWEnabled
{
    return NO;
}

- (void)setAppleProRAWEnabled:(BOOL)appleProRAWEnabled
{
    if (appleProRAWEnabled)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setAppleProRAWEnabled:] Apple ProRAW capture is not supported by this device");
}

- (AVCapturePhotoQualityPrioritization)maxPhotoQualityPrioritization
{
    return _charonMaxPhotoQualityPrioritization;
}

- (void)setMaxPhotoQualityPrioritization:(AVCapturePhotoQualityPrioritization)maxPhotoQualityPrioritization
{
    if (maxPhotoQualityPrioritization < AVCapturePhotoQualityPrioritizationSpeed || maxPhotoQualityPrioritization > AVCapturePhotoQualityPrioritizationQuality)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setMaxPhotoQualityPrioritization:] Unsupported photo quality prioritization - %ld", (long)maxPhotoQualityPrioritization);
    _charonMaxPhotoQualityPrioritization = maxPhotoQualityPrioritization;
}

// Still image stabilization arrived on AVCaptureStillImageOutput in 7.0: its own answer from then. Before 7.0 it is not
// implemented: the still image output has nothing to read (facts, "Open").
- (BOOL)isStillImageStabilizationSupported
{
    return [AVCaptureStillImageOutput instancesRespondToSelector:@selector(isStillImageStabilizationSupported)] && [super isStillImageStabilizationSupported];
}

// "NO unless you set photoSettingsForSceneMonitoring to a non-nil value" (the header); then whether the release's still
// image output would stabilize a still now, where it can.
- (BOOL)isStillImageStabilizationScene
{
    return _charonPhotoSettingsForSceneMonitoring && [AVCaptureStillImageOutput instancesRespondToSelector:@selector(isStillImageStabilizationActive)] &&
           self.stillImageStabilizationActive;
}

// One camera behind the output on every device of this release: nothing to fuse, no constituent devices.
- (BOOL)isVirtualDeviceFusionSupported
{
    return NO;
}

- (BOOL)isDualCameraFusionSupported
{
    return NO;
}

- (BOOL)isVirtualDeviceConstituentPhotoDeliverySupported
{
    return NO;
}

- (BOOL)isDualCameraDualPhotoDeliverySupported
{
    return NO;
}

- (BOOL)isVirtualDeviceConstituentPhotoDeliveryEnabled
{
    return NO;
}

- (void)setVirtualDeviceConstituentPhotoDeliveryEnabled:(BOOL)enabled
{
    if (enabled)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setVirtualDeviceConstituentPhotoDeliveryEnabled:] Virtual device constituent photo delivery is not supported in this configuration");
}

- (BOOL)isDualCameraDualPhotoDeliveryEnabled
{
    return NO;
}

- (void)setDualCameraDualPhotoDeliveryEnabled:(BOOL)enabled
{
    if (enabled)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setDualCameraDualPhotoDeliveryEnabled:] Dual Camera dual photo delivery is not supported in this configuration");
}

- (BOOL)isCameraCalibrationDataDeliverySupported
{
    return NO;
}

- (NSArray<NSNumber *> *)supportedFlashModes
{
    AVCaptureDevice *device = CharonDeviceForConnection(self.charon_videoConnection);
    if (!device)
        return @[@(AVCaptureFlashModeOff)];
    NSMutableArray<NSNumber *> *modes = [NSMutableArray arrayWithObject:@(AVCaptureFlashModeOff)];
    if ([device isFlashModeSupported:AVCaptureFlashModeOn])
        [modes addObject:@(AVCaptureFlashModeOn)];
    if ([device isFlashModeSupported:AVCaptureFlashModeAuto])
        [modes addObject:@(AVCaptureFlashModeAuto)];
    return modes;
}

// The release's still image output has no red-eye reduction.
- (BOOL)isAutoRedEyeReductionSupported
{
    return NO;
}

// NO unless photoSettingsForSceneMonitoring is set to a non-nil value (the header), and its flash mode is on the camera
// (below). With Auto, the camera's own answer is flashActive: whether a still image would fire the flash now (iOS 5). With On or Off there is no scene to judge
// and the answer stays NO.
- (BOOL)isFlashScene
{
    AVCaptureDevice *device = CharonDeviceForConnection(self.charon_videoConnection);
    return _charonPhotoSettingsForSceneMonitoring.flashMode == AVCaptureFlashModeAuto && device.hasFlash && device.flashMode == AVCaptureFlashModeAuto &&
           device.isFlashActive;
}

// A copy of the settings given (the host answers a copy).
- (AVCapturePhotoSettings *)photoSettingsForSceneMonitoring
{
    return [_charonPhotoSettingsForSceneMonitoring copy];
}

// The settings the scene is monitored for: their flash mode goes onto the camera, as a capture's does, so that the camera
// judges the scene for it (isFlashScene). Nothing fires until a capture. With none, the camera gets the application's own
// mode back once no capture is running.
- (void)setPhotoSettingsForSceneMonitoring:(AVCapturePhotoSettings *)photoSettingsForSceneMonitoring
{
    @synchronized (self) {
        _charonPhotoSettingsForSceneMonitoring = [photoSettingsForSceneMonitoring copy];
    }
    if (photoSettingsForSceneMonitoring)
        [self charon_setFlashMode:photoSettingsForSceneMonitoring.flashMode ofCamera:CharonDeviceForConnection(self.charon_videoConnection)];
    else
        [self charon_giveBackCameraFlashMode];
}

- (NSArray<AVCapturePhotoSettings *> *)preparedPhotoSettingsArray
{
    return _charonPreparedPhotoSettingsArray;
}

// The release's still image output needs no preparation, so a request is prepared once the session runs: the handler is
// called then with YES, or at once when it already runs. A later call answers the earlier handler NO, as the host does
// with no session.
- (void)setPreparedPhotoSettingsArray:(NSArray<AVCapturePhotoSettings *> *)preparedPhotoSettingsArray
                    completionHandler:(void (^)(BOOL prepared, NSError *error))completionHandler
{
    NSMutableArray *copies = [NSMutableArray arrayWithCapacity:preparedPhotoSettingsArray.count];
    for (AVCapturePhotoSettings *settings in preparedPhotoSettingsArray)
        [copies addObject:[settings copy]];
    void (^earlier)(BOOL, NSError *) = nil;
    @synchronized (self) {
        _charonPreparedPhotoSettingsArray = [copies copy];
        earlier = _charonPrepareHandler;
        _charonPrepareHandler = [completionHandler copy];
        if (_charonPrepareObserver) {
            [[NSNotificationCenter defaultCenter] removeObserver:_charonPrepareObserver];
            _charonPrepareObserver = nil;
        }
    }
    if (earlier)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ earlier(NO, nil); });
    if (!completionHandler)
        return;
    if (self.charon_videoConnection.isActive) {
        [self charon_firePrepareHandler];
        return;
    }
    __weak CharonPhotoOutput *weakSelf = self;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionDidStartRunningNotification object:nil queue:nil
                                                                usingBlock:^(NSNotification *note) {
        CharonPhotoOutput *strongSelf = weakSelf;
        if (strongSelf && [[(AVCaptureSession *)note.object outputs] containsObject:strongSelf])
            [strongSelf charon_firePrepareHandler];
    }];
    @synchronized (self) {
        if (_charonPrepareHandler)
            _charonPrepareObserver = observer;
        else
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
}

- (void)charon_firePrepareHandler
{
    void (^handler)(BOOL, NSError *) = nil;
    @synchronized (self) {
        handler = _charonPrepareHandler;
        _charonPrepareHandler = nil;
        if (_charonPrepareObserver) {
            [[NSNotificationCenter defaultCenter] removeObserver:_charonPrepareObserver];
            _charonPrepareObserver = nil;
        }
    }
    if (handler)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ handler(YES, nil); });
}

// The still image output takes a still at the size its session's preset gives. From 8.0 it has a high resolution
// still of its own, which this turns on and off; before 8.0 there is no other size to ask for.
- (BOOL)isHighResolutionCaptureEnabled
{
    return _charonHighResolutionCaptureEnabled;
}

- (void)setHighResolutionCaptureEnabled:(BOOL)highResolutionCaptureEnabled
{
    _charonHighResolutionCaptureEnabled = highResolutionCaptureEnabled;
    if ([AVCaptureStillImageOutput instancesRespondToSelector:@selector(setHighResolutionStillImageOutputEnabled:)])
        self.highResolutionStillImageOutputEnabled = highResolutionCaptureEnabled;
}

// The largest photo, of the dimensions the camera's active format offers. Before a camera with an active format
// (7.0) is behind the output it may not be set (the host's text); a 6.x camera has no active format at all.
- (CMVideoDimensions)maxPhotoDimensions
{
    return _charonMaxPhotoDimensions;
}

- (void)setMaxPhotoDimensions:(CMVideoDimensions)maxPhotoDimensions
{
    AVCaptureDevice *device = CharonDeviceForConnection(self.charon_videoConnection);
    id format = [device respondsToSelector:@selector(activeFormat)] ? [device activeFormat] : nil;
    if (!format)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setMaxPhotoDimensions:] May not be set until connected to a video source device with a non-nil activeFormat");
    CMVideoDimensions video = CMVideoFormatDescriptionGetDimensions([format formatDescription]);
    CMVideoDimensions still = [format respondsToSelector:@selector(highResolutionStillImageDimensions)] ? [format highResolutionStillImageDimensions] : video;
    BOOL offered = (maxPhotoDimensions.width == video.width && maxPhotoDimensions.height == video.height) ||
                   (maxPhotoDimensions.width == still.width && maxPhotoDimensions.height == still.height);
    if (!offered)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setMaxPhotoDimensions:] %dx%d is not one of the active format's photo dimensions (%dx%d, %dx%d)",
                          maxPhotoDimensions.width, maxPhotoDimensions.height, video.width, video.height, still.width, still.height);
    _charonMaxPhotoDimensions = maxPhotoDimensions;
}

// The port delivers a bracket as one still capture per member, in order, each delivered before the next is taken. The port keeps
// no photo of a bracket in memory (each is handed to the delegate when it is taken), so it has no count of its own to bound a
// bracket by: the answer is the largest the header can state. The device's own limit, which depends on the format and the
// preset, is not reported on 6.1.3 and is not measured here (facts/AVFoundation/AVCapturePhotoBracketSettings.md).
- (NSUInteger)maxBracketedCapturePhotoCount
{
    return CharonBracketedCapturePhotoLimit;
}

- (BOOL)isLensStabilizationDuringBracketedCaptureSupported
{
    return NO;
}

// Live Photo capture is not implemented: it needs a movie recorded around the still, which the port does not make
// (facts, "Open").
- (BOOL)isLivePhotoCaptureSupported
{
    return NO;
}

- (BOOL)isLivePhotoCaptureEnabled
{
    return NO;
}

- (void)setLivePhotoCaptureEnabled:(BOOL)livePhotoCaptureEnabled
{
    if (livePhotoCaptureEnabled)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setLivePhotoCaptureEnabled:] Live Photo movie capture is not supported on this device");
}

- (BOOL)isLivePhotoCaptureSuspended
{
    return NO;
}

- (void)setLivePhotoCaptureSuspended:(BOOL)livePhotoCaptureSuspended
{
    if (livePhotoCaptureSuspended)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setLivePhotoCaptureSuspended:] Live Photo capture may not be suspended unless livePhotoCaptureEnabled is YES");
}

- (BOOL)preservesLivePhotoCaptureSuspendedOnSessionStop
{
    return NO;
}

- (void)setPreservesLivePhotoCaptureSuspendedOnSessionStop:(BOOL)preserves
{
    if (preserves)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setPreservesLivePhotoCaptureSuspendedOnSessionStop:] Preserving LivePhotoCaptureSuspended may not be set to YES unless livePhotoCaptureSupported is YES");
}

- (BOOL)isLivePhotoAutoTrimmingEnabled
{
    return NO;
}

- (void)setLivePhotoAutoTrimmingEnabled:(BOOL)livePhotoAutoTrimmingEnabled
{
    if (livePhotoAutoTrimmingEnabled)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setLivePhotoAutoTrimmingEnabled:] May not be set unless isLivePhotoCaptureSupported = YES");
}

- (NSArray<AVVideoCodecType> *)availableLivePhotoVideoCodecTypes
{
    return @[];
}

// RAW and DNG are not implemented (facts, "Open"): no RAW sample comes from the release's still image output, and no DNG
// is written; a sample that is not RAW is refused with the host's text.
+ (NSData *)DNGPhotoDataRepresentationForRawSampleBuffer:(CMSampleBufferRef)rawSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer
{
    CMFormatDescriptionRef format = rawSampleBuffer ? CMSampleBufferGetFormatDescription(rawSampleBuffer) : NULL;
    FourCharCode type = format ? CMFormatDescriptionGetMediaSubType(format) : 0;
    if (!CharonIsBayerRAWPixelFormat(type) && !CharonIsAppleProRAWPixelFormat(type))
        CharonOutputRaise(@"*** +[AVCapturePhotoOutput DNGPhotoDataRepresentationForRawSampleBuffer:previewPhotoSampleBuffer:] Unrecognized raw format %c%c%c%c",
                          (char)(type >> 24), (char)(type >> 16), (char)(type >> 8), (char)type);
    return nil;
}

// One lens with no distortion correction of its own on every camera of this release.
- (BOOL)isContentAwareDistortionCorrectionSupported
{
    return NO;
}

- (BOOL)isContentAwareDistortionCorrectionEnabled
{
    return NO;
}

- (void)setContentAwareDistortionCorrectionEnabled:(BOOL)enabled
{
    if (enabled)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setContentAwareDistortionCorrectionEnabled:] Content aware distortion correction is not supported in this configuration");
}

// No camera of this release measures depth, so there is no depth, no portrait matte and no segmentation matte.
- (BOOL)isDepthDataDeliverySupported
{
    return NO;
}

- (BOOL)isDepthDataDeliveryEnabled
{
    return NO;
}

- (void)setDepthDataDeliveryEnabled:(BOOL)enabled
{
    if (enabled)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setDepthDataDeliveryEnabled:] Depth data delivery is not supported in the current configuration");
}

- (BOOL)isPortraitEffectsMatteDeliverySupported
{
    return NO;
}

- (BOOL)isPortraitEffectsMatteDeliveryEnabled
{
    return NO;
}

- (void)setPortraitEffectsMatteDeliveryEnabled:(BOOL)enabled
{
    if (enabled)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setPortraitEffectsMatteDeliveryEnabled:] Portrait effects matte delivery is not supported in the current configuration");
}

- (NSArray<AVSemanticSegmentationMatteType> *)availableSemanticSegmentationMatteTypes
{
    return @[];
}

- (NSArray<AVSemanticSegmentationMatteType> *)enabledSemanticSegmentationMatteTypes
{
    return @[];
}

- (void)setEnabledSemanticSegmentationMatteTypes:(NSArray<AVSemanticSegmentationMatteType> *)types
{
    NSMutableSet *illegal = [NSMutableSet setWithArray:types ?: @[]];
    [illegal minusSet:[NSSet setWithArray:self.availableSemanticSegmentationMatteTypes]];
    if (illegal.count)
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput setEnabledSemanticSegmentationMatteTypes:] enabledSemanticSegmentationMatteTypes may only contain matte types present in availableSemanticSegmentationMatteTypes. Illegal matte types: %@", illegal);
}

// The longest side of the preview. The header (AVCapturePhotoOutput.h:1597-1598) honours width and height only up to the display
// dimensions, and when the two differ in aspect from the photo the larger side is honoured while the photo's aspect is kept; with
// no dimensions, the display's.
static size_t CharonPreviewLongestSide(NSDictionary *preview)
{
    UIScreen *screen = [UIScreen mainScreen];
    size_t display = (size_t)(MAX(screen.bounds.size.width, screen.bounds.size.height) * screen.scale);
    NSNumber *width = preview[(__bridge NSString *)kCVPixelBufferWidthKey], *height = preview[(__bridge NSString *)kCVPixelBufferHeightKey];
    if (!width || !height)
        return display;
    return MIN((size_t)MAX(width.unsignedIntegerValue, height.unsignedIntegerValue), display);
}

// Whether the flash fired for a still: bit 0 of the Exif Flash tag the release attaches to the still's sample buffer.
static BOOL CharonStillFlashFired(CMSampleBufferRef still)
{
    CFDictionaryRef exif = still ? CMGetAttachment(still, kCGImagePropertyExifDictionary, NULL) : NULL;
    NSNumber *flash = exif ? ((__bridge NSDictionary *)exif)[(__bridge NSString *)kCGImagePropertyExifFlash] : nil;
    return (flash.unsignedIntegerValue & 1) != 0;
}

// The dimensions of the preview or the thumbnail of a photo of `photo`: its longest side `longest`, or the photo's own
// when that is smaller, and the photo's aspect ratio.
static CMVideoDimensions CharonPreviewDimensions(CMVideoDimensions photo, size_t longest)
{
    if (photo.width <= 0 || photo.height <= 0)
        return (CMVideoDimensions){0, 0};
    double scale = MIN(1.0, (double)longest / MAX(photo.width, photo.height));
    return (CMVideoDimensions){MAX(1, (int32_t)llround(photo.width * scale)), MAX(1, (int32_t)llround(photo.height * scale))};
}

// A 32BGRA picture as bi-planar 4:2:0 YCbCr, video range (420v) or full range (420f), by ITU-R BT.601, converted by
// vImageConvert_ARGB8888To420Yp8_CbCr8 (libAccelerateBackports before 8.0), each chroma sample the mean of its two by two
// pixels. The buffer says its matrix (kCVImageBufferYCbCrMatrix_ITU_R_601_4). NULL on failure.
static CVPixelBufferRef CharonCreateYCbCrBuffer(CVPixelBufferRef bgra, OSType pixelFormat)
{
    size_t width = CVPixelBufferGetWidth(bgra), height = CVPixelBufferGetHeight(bgra);
    CVPixelBufferRef ycbcr = NULL;
    NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, (__bridge CFDictionaryRef)attributes, &ycbcr) != kCVReturnSuccess)
        return NULL;
    // Video range takes Y 16...235 and Cb, Cr 16...240, full range 0...255 for all three.
    BOOL full = pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    vImage_YpCbCrPixelRange range = full ? (vImage_YpCbCrPixelRange){0, 128, 255, 255, 255, 0, 255, 0}
                                         : (vImage_YpCbCrPixelRange){16, 128, 235, 240, 235, 16, 240, 16};
    vImage_ARGBToYpCbCr conversion;
    vImage_Error error = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &range, &conversion,
                                                                       kvImageARGB8888, kvImage420Yp8_CbCr8, kvImageNoFlags);
    if (error == kvImageNoError) {
        CVPixelBufferLockBaseAddress(bgra, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferLockBaseAddress(ycbcr, 0);
        vImage_Buffer source = {CVPixelBufferGetBaseAddress(bgra), height, width, CVPixelBufferGetBytesPerRow(bgra)};
        vImage_Buffer luma = {CVPixelBufferGetBaseAddressOfPlane(ycbcr, 0), CVPixelBufferGetHeightOfPlane(ycbcr, 0),
                              CVPixelBufferGetWidthOfPlane(ycbcr, 0), CVPixelBufferGetBytesPerRowOfPlane(ycbcr, 0)};
        vImage_Buffer chroma = {CVPixelBufferGetBaseAddressOfPlane(ycbcr, 1), CVPixelBufferGetHeightOfPlane(ycbcr, 1),
                                CVPixelBufferGetWidthOfPlane(ycbcr, 1), CVPixelBufferGetBytesPerRowOfPlane(ycbcr, 1)};
        // The pixels are B, G, R, A in memory: the map takes the channels of ARGB from them.
        const uint8_t permute[4] = {3, 2, 1, 0};
        error = vImageConvert_ARGB8888To420Yp8_CbCr8(&source, &luma, &chroma, &conversion, permute, kvImageNoFlags);
        CVPixelBufferUnlockBaseAddress(ycbcr, 0);
        CVPixelBufferUnlockBaseAddress(bgra, kCVPixelBufferLock_ReadOnly);
    }
    if (error != kvImageNoError) {
        NSLog(@"AVCapturePhotoOutput: the preview photo could not be converted to 4:2:0 (vImage error %ld)", (long)error);
        CVPixelBufferRelease(ycbcr);
        return NULL;
    }
    CVBufferSetAttachment(ycbcr, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
    return ycbcr;
}

// The preview sample buffer: the still drawn into a 32BGRA pixel buffer of the resolved preview dimensions, in the
// pixel format asked (32BGRA, or 420v and 420f converted from it), with the still's presentation time.
static CMSampleBufferRef CharonCreatePreviewSample(CMSampleBufferRef photo, CMVideoDimensions dimensions, OSType pixelFormat)
{
    if (!photo || dimensions.width <= 0 || dimensions.height <= 0)
        return NULL;
    size_t width = (size_t)dimensions.width, height = (size_t)dimensions.height;
    CGImageRef image = CharonCreatePhotoImage(photo, MAX(width, height));
    if (!image)
        return NULL;
    CVPixelBufferRef pixels = NULL;
    NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attributes, &pixels) != kCVReturnSuccess) {
        CGImageRelease(image);
        return NULL;
    }
    CVPixelBufferLockBaseAddress(pixels, 0);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(pixels), width, height, 8, CVPixelBufferGetBytesPerRow(pixels), space,
                                                 kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    if (context) {
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
        CGContextRelease(context);
    }
    CVPixelBufferUnlockBaseAddress(pixels, 0);
    CGImageRelease(image);
    if (context && pixelFormat != kCVPixelFormatType_32BGRA) {
        CVPixelBufferRef converted = CharonCreateYCbCrBuffer(pixels, pixelFormat);
        CVPixelBufferRelease(pixels);
        pixels = converted;
        if (!pixels)
            return NULL;
    }
    CMVideoFormatDescriptionRef description = NULL;
    CMSampleBufferRef sample = NULL;
    CMSampleTimingInfo timing = {kCMTimeInvalid, CMSampleBufferGetPresentationTimeStamp(photo), kCMTimeInvalid};
    if (context && CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixels, &description) == noErr)
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixels, true, NULL, NULL, description, &timing, &sample);
    if (description)
        CFRelease(description);
    CVPixelBufferRelease(pixels);
    return sample;
}

// The embedded thumbnail, where the Exif standard keeps it: IFD1 of the TIFF block in the JPEG's APP1 "Exif" segment, a
// JPEG (Compression 6) found by JPEGInterchangeFormat and JPEGInterchangeFormatLength. ImageIO writes one only from 8.0
// (kCGImageDestinationEmbedThumbnail), so the segment is read and written here. IFD1 holds what the host's
// +JPEGPhotoDataRepresentationForJPEGSampleBuffer:previewPhotoSampleBuffer: writes for the preview it embeds (measured,
// facts "The embedded thumbnail"): Compression, XResolution and YResolution 72/1, ResolutionUnit inches, the thumbnail's
// offset and length; and the thumbnail JPEG has no APPn segment of its own, as the host's has none.
static const size_t CharonHostThumbnailLongestSide = 160; // the host's thumbnail of a larger preview (measured, facts)

static uint16_t CharonTIFF16(const uint8_t *p, BOOL big)
{
    return big ? (uint16_t)(p[0] << 8 | p[1]) : (uint16_t)(p[1] << 8 | p[0]);
}

static uint32_t CharonTIFF32(const uint8_t *p, BOOL big)
{
    return big ? (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]
               : (uint32_t)p[3] << 24 | (uint32_t)p[2] << 16 | (uint32_t)p[1] << 8 | p[0];
}

static void CharonTIFFAppend16(NSMutableData *data, uint16_t value, BOOL big)
{
    uint8_t bytes[2] = {(uint8_t)(big ? value >> 8 : value), (uint8_t)(big ? value : value >> 8)};
    [data appendBytes:bytes length:2];
}

static void CharonTIFFAppend32(NSMutableData *data, uint32_t value, BOOL big)
{
    CharonTIFFAppend16(data, (uint16_t)(big ? value >> 16 : value), big);
    CharonTIFFAppend16(data, (uint16_t)(big ? value : value >> 16), big);
}

// One IFD entry holding one value in its value field: a SHORT is left-justified in it, as TIFF 6.0 has it.
static void CharonTIFFAppendEntry(NSMutableData *data, uint16_t tag, uint16_t type, uint32_t value, BOOL big)
{
    CharonTIFFAppend16(data, tag, big);
    CharonTIFFAppend16(data, type, big);
    CharonTIFFAppend32(data, 1, big);
    if (type == 3) {
        CharonTIFFAppend16(data, (uint16_t)value, big);
        CharonTIFFAppend16(data, 0, big);
    } else {
        CharonTIFFAppend32(data, value, big);
    }
}

// The APP1 "Exif" segment of a JPEG, from its marker to its end; NO when the JPEG has none before its image data.
static BOOL CharonJPEGFindExif(const uint8_t *bytes, size_t length, size_t *start, size_t *end)
{
    size_t at = 2;
    while (at + 4 <= length && bytes[at] == 0xFF && bytes[at + 1] != 0xDA && bytes[at + 1] != 0xD9) {
        size_t segment = (size_t)bytes[at + 2] << 8 | bytes[at + 3];
        if (segment < 2 || at + 2 + segment > length)
            return NO;
        if (bytes[at + 1] == 0xE1 && segment >= 8 && memcmp(bytes + at + 4, "Exif\0\0", 6) == 0) {
            *start = at;
            *end = at + 2 + segment;
            return YES;
        }
        at += 2 + segment;
    }
    return NO;
}

// Where IFD0 of a TIFF block links to IFD1 (the offset of its "next IFD" field), and the block's byte order; NO when it
// is not a TIFF block.
static BOOL CharonTIFFLink(const uint8_t *tiff, size_t length, BOOL *big, size_t *link)
{
    if (length < 8 || tiff[0] != tiff[1] || (tiff[0] != 'M' && tiff[0] != 'I'))
        return NO;
    *big = tiff[0] == 'M';
    uint32_t ifd0 = CharonTIFF32(tiff + 4, *big);
    if (CharonTIFF16(tiff + 2, *big) != 42 || ifd0 < 8 || (size_t)ifd0 + 2 > length)
        return NO;
    *link = ifd0 + 2 + 12 * (size_t)CharonTIFF16(tiff + ifd0, *big);
    return *link + 4 <= length;
}

static BOOL CharonIsJPEG(NSData *data)
{
    const uint8_t *bytes = data.bytes;
    return data.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8;
}

// The thumbnail a JPEG carries in IFD1 of its Exif, or nil.
static NSData *CharonJPEGThumbnail(NSData *jpeg)
{
    const uint8_t *bytes = jpeg.bytes;
    size_t start = 0, end = 0, link = 0;
    BOOL big = YES;
    if (!CharonIsJPEG(jpeg) || !CharonJPEGFindExif(bytes, jpeg.length, &start, &end))
        return nil;
    const uint8_t *tiff = bytes + start + 10;
    size_t length = end - start - 10;
    if (!CharonTIFFLink(tiff, length, &big, &link))
        return nil;
    uint32_t ifd1 = CharonTIFF32(tiff + link, big), offset = 0, size = 0;
    if (ifd1 < 8 || (size_t)ifd1 + 2 > length)
        return nil;
    size_t entries = CharonTIFF16(tiff + ifd1, big);
    if (ifd1 + 2 + 12 * entries > length)
        return nil;
    for (size_t entry = 0; entry < entries; entry++) {
        const uint8_t *field = tiff + ifd1 + 2 + 12 * entry;
        if (CharonTIFF16(field, big) == 0x0201)
            offset = CharonTIFF32(field + 8, big);
        else if (CharonTIFF16(field, big) == 0x0202)
            size = CharonTIFF32(field + 8, big);
    }
    if (!offset || !size || (size_t)offset + size > length)
        return nil;
    return [NSData dataWithBytes:tiff + offset length:size];
}

// `jpeg` with `thumbnail` (a JPEG) in IFD1 of its Exif. The TIFF block of the Exif segment is kept as it is, and IFD1
// with the thumbnail follows it, linked from IFD0; an IFD1 already there is unlinked, its bytes left where nothing
// points. A JPEG with no Exif segment gets one, with an IFD0 of no entries, after SOI and a JFIF APP0 when it has one.
// nil when either is not a JPEG, or when the segment would be longer than a JPEG segment can be (65535 bytes).
static NSData *CharonJPEGWithThumbnail(NSData *jpeg, NSData *thumbnail)
{
    if (!CharonIsJPEG(jpeg) || !CharonIsJPEG(thumbnail))
        return nil;
    const uint8_t *bytes = jpeg.bytes;
    size_t length = jpeg.length, start = 0, end = 0, link = 0;
    BOOL big = YES;
    NSMutableData *tiff;
    if (CharonJPEGFindExif(bytes, length, &start, &end)) {
        tiff = [NSMutableData dataWithBytes:bytes + start + 10 length:end - start - 10];
        if (!CharonTIFFLink(tiff.bytes, tiff.length, &big, &link))
            return nil;
    } else {
        static const uint8_t empty[] = {'M', 'M', 0, 42, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0};
        tiff = [NSMutableData dataWithBytes:empty length:sizeof empty];
        link = 10;
        start = end = bytes[2] == 0xFF && bytes[3] == 0xE0 && length >= 6 ? 4 + ((size_t)bytes[4] << 8 | bytes[5]) : 2;
        if (end > length)
            return nil;
    }
    if (tiff.length % 2)
        [tiff appendBytes:"" length:1]; // an IFD begins on a word boundary (TIFF 6.0)
    uint32_t ifd1 = (uint32_t)tiff.length, entries = 6;
    uint32_t resolution = ifd1 + 2 + 12 * entries + 4, offset = resolution + 16;
    NSMutableData *linked = [NSMutableData data];
    CharonTIFFAppend32(linked, ifd1, big);
    [tiff replaceBytesInRange:NSMakeRange(link, 4) withBytes:linked.bytes];
    CharonTIFFAppend16(tiff, (uint16_t)entries, big);
    CharonTIFFAppendEntry(tiff, 0x0103, 3, 6, big);          // Compression: JPEG
    CharonTIFFAppendEntry(tiff, 0x011A, 5, resolution, big); // XResolution
    CharonTIFFAppendEntry(tiff, 0x011B, 5, resolution + 8, big); // YResolution
    CharonTIFFAppendEntry(tiff, 0x0128, 3, 2, big);          // ResolutionUnit: inches
    CharonTIFFAppendEntry(tiff, 0x0201, 4, offset, big);     // JPEGInterchangeFormat
    CharonTIFFAppendEntry(tiff, 0x0202, 4, (uint32_t)thumbnail.length, big); // JPEGInterchangeFormatLength
    CharonTIFFAppend32(tiff, 0, big);                        // no IFD after IFD1
    for (int axis = 0; axis < 2; axis++) {
        CharonTIFFAppend32(tiff, 72, big);
        CharonTIFFAppend32(tiff, 1, big);
    }
    [tiff appendData:thumbnail];
    size_t segment = 2 + 6 + tiff.length;
    if (segment > 0xFFFF)
        return nil;
    NSMutableData *result = [NSMutableData dataWithBytes:bytes length:start];
    uint8_t header[10] = {0xFF, 0xE1, (uint8_t)(segment >> 8), (uint8_t)segment, 'E', 'x', 'i', 'f', 0, 0};
    [result appendBytes:header length:sizeof header];
    [result appendData:tiff];
    [result appendBytes:bytes + end length:length - end];
    return result;
}

// An image as the JPEG of a thumbnail: ImageIO's JPEG at `quality` (nil: ImageIO's own), without its APPn segments.
static NSData *CharonThumbnailJPEG(CGImageRef image, NSNumber *quality)
{
    NSMutableData *written = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)written, CFSTR("public.jpeg"), 1, NULL);
    if (!destination)
        return nil;
    NSDictionary *properties = quality ? @{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality: quality} : nil;
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
    BOOL finished = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    if (!finished || !CharonIsJPEG(written))
        return nil;
    const uint8_t *bytes = written.bytes;
    size_t length = written.length, at = 2;
    NSMutableData *bare = [NSMutableData dataWithBytes:bytes length:2];
    while (at + 4 <= length && bytes[at] == 0xFF && bytes[at + 1] != 0xDA) {
        size_t segment = (size_t)bytes[at + 2] << 8 | bytes[at + 3];
        if (segment < 2 || at + 2 + segment > length)
            return nil;
        if (bytes[at + 1] < 0xE0 || bytes[at + 1] > 0xEF)
            [bare appendBytes:bytes + at length:2 + segment];
        at += 2 + segment;
    }
    [bare appendBytes:bytes + at length:length - at];
    return bare;
}

// `jpeg` with the picture of `small` (a sample at the thumbnail's own dimensions) as its thumbnail. One written at
// ImageIO's own quality that does not fit the segment is written again at its lowest; nil when that does not fit either.
static NSData *CharonJPEGEmbeddingThumbnailOf(NSData *jpeg, CMSampleBufferRef small)
{
    CGImageRef image = small ? CharonCreatePhotoImage(small, 0) : NULL;
    if (!image)
        return nil;
    NSData *result = CharonJPEGWithThumbnail(jpeg, CharonThumbnailJPEG(image, nil)) ?: CharonJPEGWithThumbnail(jpeg, CharonThumbnailJPEG(image, @0.0));
    CGImageRelease(image);
    return result;
}

// The longest side of the thumbnail a format asks for: the larger of its AVVideoWidthKey and AVVideoHeightKey, given
// together (the header, AVCapturePhotoOutput.h:1597-1598: the larger dimension is honoured and the photo's aspect kept); with neither, the host's own thumbnail size.
static size_t CharonThumbnailLongestSide(NSDictionary *format)
{
    NSNumber *width = format[AVVideoWidthKey], *height = format[AVVideoHeightKey];
    if (!width || !height)
        return CharonHostThumbnailLongestSide;
    return MAX(1, (size_t)MAX(width.unsignedIntegerValue, height.unsignedIntegerValue));
}

// The still with a thumbnail of `dimensions` embedded: a sample buffer with the still's format, timing and attachments
// whose data is the still's own JPEG with the thumbnail in its Exif. NULL when it cannot be made.
static CMSampleBufferRef CharonCreateSampleWithThumbnail(CMSampleBufferRef still, CMVideoDimensions dimensions)
{
    CMBlockBufferRef block = still ? CMSampleBufferGetDataBuffer(still) : NULL;
    CMFormatDescriptionRef format = still ? CMSampleBufferGetFormatDescription(still) : NULL;
    if (!block || !format || CMFormatDescriptionGetMediaSubType(format) != kCMVideoCodecType_JPEG)
        return NULL;
    NSMutableData *jpeg = [NSMutableData dataWithLength:CMBlockBufferGetDataLength(block)];
    if (CMBlockBufferCopyDataBytes(block, 0, jpeg.length, jpeg.mutableBytes) != kCMBlockBufferNoErr)
        return NULL;
    CMSampleBufferRef small = CharonCreatePreviewSample(still, dimensions, kCVPixelFormatType_32BGRA);
    NSData *embedded = CharonJPEGEmbeddingThumbnailOf(jpeg, small);
    if (small)
        CFRelease(small);
    CMBlockBufferRef data = NULL;
    if (!embedded || CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, embedded.length, kCFAllocatorDefault, NULL, 0, embedded.length,
                                                        kCMBlockBufferAssureMemoryNowFlag, &data) != kCMBlockBufferNoErr)
        return NULL;
    CMSampleBufferRef sample = NULL;
    CMSampleTimingInfo timing = {kCMTimeInvalid, CMSampleBufferGetPresentationTimeStamp(still), kCMTimeInvalid};
    size_t size = embedded.length;
    if (CMBlockBufferReplaceDataBytes(embedded.bytes, data, 0, embedded.length) == kCMBlockBufferNoErr)
        CMSampleBufferCreate(kCFAllocatorDefault, data, true, NULL, NULL, format, 1, 1, &timing, 1, &size, &sample);
    CFRelease(data);
    for (int propagates = 0; sample && propagates < 2; propagates++) {
        CMAttachmentMode mode = propagates ? kCMAttachmentMode_ShouldPropagate : kCMAttachmentMode_ShouldNotPropagate;
        CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, still, mode);
        if (attachments) {
            CMSetAttachments(sample, attachments, mode);
            CFRelease(attachments);
        }
    }
    return sample;
}

// The release's own JPEG of the still, with the metadata attached to its sample buffer (the settings' own, at capture),
// and a thumbnail in its Exif: the preview given, no longer on its longest side than the host's thumbnail (the host
// embeds it so, measured); with no preview, the thumbnail the sample's own JPEG carries (the capture's, when its
// settings asked for one), which the release's repackaging does not keep. The host keeps no thumbnail the sample
// carries (facts).
+ (NSData *)JPEGPhotoDataRepresentationForJPEGSampleBuffer:(CMSampleBufferRef)JPEGSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer
{
    CMFormatDescriptionRef format = JPEGSampleBuffer ? CMSampleBufferGetFormatDescription(JPEGSampleBuffer) : NULL;
    if (!format || CMFormatDescriptionGetMediaSubType(format) != kCMVideoCodecType_JPEG)
        CharonOutputRaise(@"*** +[AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:previewPhotoSampleBuffer:] Not a jpeg sample buffer");
    NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:JPEGSampleBuffer];
    if (!data)
        return nil;
    NSData *thumbnailed = nil;
    if (previewPhotoSampleBuffer) {
        CMFormatDescriptionRef previewFormat = CMSampleBufferGetFormatDescription(previewPhotoSampleBuffer);
        CMVideoDimensions preview = previewFormat ? CMVideoFormatDescriptionGetDimensions(previewFormat) : (CMVideoDimensions){0, 0};
        CMSampleBufferRef small = CharonCreatePreviewSample(previewPhotoSampleBuffer, CharonPreviewDimensions(preview, CharonHostThumbnailLongestSide),
                                                            kCVPixelFormatType_32BGRA);
        thumbnailed = CharonJPEGEmbeddingThumbnailOf(data, small);
        if (small)
            CFRelease(small);
    } else {
        CMBlockBufferRef block = CMSampleBufferGetDataBuffer(JPEGSampleBuffer);
        NSMutableData *own = [NSMutableData dataWithLength:block ? CMBlockBufferGetDataLength(block) : 0];
        NSData *thumbnail = block && CMBlockBufferCopyDataBytes(block, 0, own.length, own.mutableBytes) == kCMBlockBufferNoErr ? CharonJPEGThumbnail(own) : nil;
        if (!thumbnail || CharonJPEGThumbnail(data))
            return data;
        thumbnailed = CharonJPEGWithThumbnail(data, thumbnail);
    }
    if (!thumbnailed)
        NSLog(@"AVCapturePhotoOutput: the thumbnail could not be embedded in the JPEG; it is written without one");
    return thumbnailed ?: data;
}

// The header's rules for a request, each broken one refused with NSInvalidArgumentException before anything is captured.
// The first is the host's own, with its text (it refuses a request with no connection first); the host cannot show the
// others without a camera, so their texts are the port's, each naming the rule. Every feature this output does not
// offer is refused here as a device without it refuses it.
- (void)charon_checkSettings:(AVCapturePhotoSettings *)settings connection:(AVCaptureConnection *)connection
{
    NSString *method = @"*** -[AVCapturePhotoOutput capturePhotoWithSettings:delegate:]";
    if (!connection || !connection.isEnabled || !connection.isActive)
        CharonOutputRaise(@"%@ No active and enabled video connection", method);
    @synchronized (self) {
        if ([_charonCapturedUniqueIDs containsObject:@(settings.uniqueID)])
            CharonOutputRaise(@"%@ settings.uniqueID %lld has already been used for a capture; use +photoSettingsFromPhotoSettings: for a new one", method, settings.uniqueID);
    }
    // RAW rules.
    if (settings.rawPhotoPixelFormatType && ![self.availableRawPhotoPixelFormatTypes containsObject:@(settings.rawPhotoPixelFormatType)])
        CharonOutputRaise(@"%@ rawPhotoPixelFormatType must be present in availableRawPhotoPixelFormatTypes (%@)", method, self.availableRawPhotoPixelFormatTypes);
    // Processed format rules.
    NSDictionary *format = settings.format;
    NSNumber *pixels = format[(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey];
    NSString *codec = format[AVVideoCodecKey];
    if (pixels && ![self.availablePhotoPixelFormatTypes containsObject:pixels])
        CharonOutputRaise(@"%@ format's kCVPixelBufferPixelFormatTypeKey %@ must be present in availablePhotoPixelFormatTypes (%@)", method, pixels, self.availablePhotoPixelFormatTypes);
    if (codec && ![self.availablePhotoCodecTypes containsObject:codec])
        CharonOutputRaise(@"%@ format's AVVideoCodecKey %@ must be present in availablePhotoCodecTypes (%@)", method, codec, self.availablePhotoCodecTypes);
    NSString *fileType = settings.processedFileType;
    if (fileType && (![self.availablePhotoFileTypes containsObject:fileType] ||
                     !(pixels ? [[self supportedPhotoPixelFormatTypesForFileType:fileType] containsObject:pixels]
                              : [[self supportedPhotoCodecTypesForFileType:fileType] containsObject:codec])))
        CharonOutputRaise(@"%@ processedFileType %@ must be present in availablePhotoFileTypes (%@) and support the format", method, fileType, self.availablePhotoFileTypes);
    if (settings.photoQualityPrioritization > self.maxPhotoQualityPrioritization)
        CharonOutputRaise(@"%@ photoQualityPrioritization %ld may not be greater than maxPhotoQualityPrioritization %ld", method,
                          (long)settings.photoQualityPrioritization, (long)self.maxPhotoQualityPrioritization);
    // Flash rules.
    if (![self.supportedFlashModes containsObject:@(settings.flashMode)])
        CharonOutputRaise(@"%@ flashMode %ld must be present in supportedFlashModes (%@)", method, (long)settings.flashMode, self.supportedFlashModes);
    // Live Photo rules.
    if (settings.livePhotoMovieFileURL && !self.isLivePhotoCaptureEnabled)
        CharonOutputRaise(@"%@ livePhotoMovieFileURL may only be set when livePhotoCaptureEnabled is YES", method);
    // The resolution, and what the output must have turned on for the request to ask for it.
    if (settings.isHighResolutionPhotoEnabled && !self.isHighResolutionCaptureEnabled)
        CharonOutputRaise(@"%@ highResolutionPhotoEnabled may only be YES when highResolutionCaptureEnabled is YES", method);
    CMVideoDimensions asked = settings.maxPhotoDimensions, allowed = self.maxPhotoDimensions;
    if ((asked.width || asked.height) && (asked.width > allowed.width || asked.height > allowed.height))
        CharonOutputRaise(@"%@ maxPhotoDimensions %dx%d may not be greater than the output's maxPhotoDimensions %dx%d", method, asked.width, asked.height, allowed.width, allowed.height);
    if (settings.isDepthDataDeliveryEnabled && !self.isDepthDataDeliveryEnabled)
        CharonOutputRaise(@"%@ depthDataDeliveryEnabled may only be YES when the output's depthDataDeliveryEnabled is YES", method);
    if (settings.isPortraitEffectsMatteDeliveryEnabled && !self.isPortraitEffectsMatteDeliveryEnabled)
        CharonOutputRaise(@"%@ portraitEffectsMatteDeliveryEnabled may only be YES when the output's portraitEffectsMatteDeliveryEnabled is YES", method);
    NSMutableSet *mattes = [NSMutableSet setWithArray:settings.enabledSemanticSegmentationMatteTypes];
    [mattes minusSet:[NSSet setWithArray:self.enabledSemanticSegmentationMatteTypes]];
    if (mattes.count)
        CharonOutputRaise(@"%@ enabledSemanticSegmentationMatteTypes may only contain the output's enabledSemanticSegmentationMatteTypes: %@", method, mattes);
    if (settings.isCameraCalibrationDataDeliveryEnabled && !self.isCameraCalibrationDataDeliverySupported)
        CharonOutputRaise(@"%@ cameraCalibrationDataDeliveryEnabled may only be YES when cameraCalibrationDataDeliverySupported is YES", method);
    if (settings.isDualCameraDualPhotoDeliveryEnabled && !self.isDualCameraDualPhotoDeliveryEnabled)
        CharonOutputRaise(@"%@ dualCameraDualPhotoDeliveryEnabled may only be YES when the output's dualCameraDualPhotoDeliveryEnabled is YES", method);
    if (settings.virtualDeviceConstituentPhotoDeliveryEnabledDevices.count && !self.isVirtualDeviceConstituentPhotoDeliveryEnabled)
        CharonOutputRaise(@"%@ virtualDeviceConstituentPhotoDeliveryEnabledDevices may only be set when the output's virtualDeviceConstituentPhotoDeliveryEnabled is YES", method);
    if (settings.isAutoContentAwareDistortionCorrectionEnabled && !self.isContentAwareDistortionCorrectionEnabled)
        CharonOutputRaise(@"%@ autoContentAwareDistortionCorrectionEnabled may only be YES when the output's contentAwareDistortionCorrectionEnabled is YES", method);
    // The preview: a pixel format available (checked when set too) and a width with a height.
    NSDictionary *preview = settings.previewPhotoFormat;
    if (preview && ![settings.availablePreviewPhotoPixelFormatTypes containsObject:preview[(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey]])
        CharonOutputRaise(@"%@ previewPhotoFormat's pixel format type must be present in availablePreviewPhotoPixelFormatTypes", method);
    if (preview && (preview[(__bridge NSString *)kCVPixelBufferWidthKey] == nil) != (preview[(__bridge NSString *)kCVPixelBufferHeightKey] == nil))
        CharonOutputRaise(@"%@ previewPhotoFormat must give both kCVPixelBufferWidthKey and kCVPixelBufferHeightKey, or neither", method);
    // The thumbnail: the header (AVCapturePhotoOutput.h:1617-1618) requires both width and height when dimensions are given.
    NSDictionary *thumbnail = settings.embeddedThumbnailPhotoFormat;
    if (thumbnail && (thumbnail[AVVideoWidthKey] == nil) != (thumbnail[AVVideoHeightKey] == nil))
        CharonOutputRaise(@"%@ embeddedThumbnailPhotoFormat must give both AVVideoWidthKey and AVVideoHeightKey, or neither", method);
}

// The settings' metadata onto the still's sample buffer, the dictionaries merged into those the release attached (the
// settings' values win), so the JPEG of the still (+jpegStillImageNSDataRepresentation:, and
// +JPEGPhotoDataRepresentationForJPEGSampleBuffer:previewPhotoSampleBuffer:) carries them.
static void CharonAttachMetadata(CMSampleBufferRef still, NSDictionary *metadata)
{
    if (!still)
        return;
    [metadata enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        id existing = (__bridge id)CMGetAttachment(still, (__bridge CFStringRef)key, NULL);
        if ([value isKindOfClass:[NSDictionary class]] && [existing isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *merged = [existing mutableCopy];
            [merged addEntriesFromDictionary:value];
            value = merged;
        }
        CMSetAttachment(still, (__bridge CFStringRef)key, (__bridge CFTypeRef)value, kCMAttachmentMode_ShouldPropagate);
    }];
}


// The bracket's own rules this output checks at capture: the count against maxBracketedCapturePhotoCount, and lens
// stabilization, which the release cannot do, so a YES is refused as the header says (AVCapturePhoto.h, bracket rules).
- (void)charon_checkBracket:(AVCapturePhotoBracketSettings *)bracket
{
    NSString *method = @"*** -[AVCapturePhotoOutput capturePhotoWithSettings:delegate:]";
    if (bracket.bracketedSettings.count > self.maxBracketedCapturePhotoCount)
        CharonOutputRaise(@"%@ bracketedSettings.count %lu must be <= maxBracketedCapturePhotoCount %lu", method,
                          (unsigned long)bracket.bracketedSettings.count, (unsigned long)self.maxBracketedCapturePhotoCount);
    if (bracket.isLensStabilizationEnabled && !self.isLensStabilizationDuringBracketedCaptureSupported)
        CharonOutputRaise(@"%@ lensStabilizationEnabled may only be YES when lensStabilizationDuringBracketedCaptureSupported is YES", method);
}

// The camera's exposure bias, set through the lock the header requires (setExposureTargetBias: throws unless the camera is
// locked). 6.1.3 has no public bias: the port's private pair (AVFoundationDemand8.m) is the setter the port drives for
// -setExposureTargetBias:completionHandler:, and the same setter is used here.
- (void)charon_setBias:(float)bias ofCamera:(AVCaptureDevice *)camera
{
    NSError *error = nil;
    if (![camera lockForConfiguration:&error]) {
        NSLog(@"AVCapturePhotoOutput: the camera could not be locked to set its exposure bias to %f; it stays as it is: %@", bias, error);
        return;
    }
    [camera setExposureTargetBias:bias completionHandler:nil];
    [camera unlockForConfiguration];
}

// The camera's exposure duration and gain, set through the lock, through the release's private pair above. The gain's unit on the
// 4S is not measured (no device attached): the manual member's ISO is passed as the gain (facts, "Manual exposure", device-unverified).
- (void)charon_setExposure:(CMTime)duration gain:(float)gain ofCamera:(AVCaptureDevice *)camera
{
    NSError *error = nil;
    if (![camera lockForConfiguration:&error]) {
        NSLog(@"AVCapturePhotoOutput: the camera could not be locked to set its exposure; it stays as it is: %@", error);
        return;
    }
    [camera setExposureDuration:duration];
    [camera setExposureGain:gain];
    [camera unlockForConfiguration];
}

// The exposure one bracket member asks for, applied to the camera before its still: an auto member's bias through the setter above,
// a manual member's duration and ISO (as the gain) through the private pair. The measurement and the reasons are in
// facts/AVFoundation/AVCapturePhotoBracketSettings.md.
- (void)charon_applyBracket:(AVCaptureBracketedStillImageSettings *)bracket toCamera:(AVCaptureDevice *)camera
{
    if (!camera)
        return;
    if ([bracket isKindOfClass:[AVCaptureAutoExposureBracketedStillImageSettings class]])
        [self charon_setBias:((AVCaptureAutoExposureBracketedStillImageSettings *)bracket).exposureTargetBias ofCamera:camera];
    else if ([bracket isKindOfClass:[AVCaptureManualExposureBracketedStillImageSettings class]]) {
        AVCaptureManualExposureBracketedStillImageSettings *manual = (AVCaptureManualExposureBracketedStillImageSettings *)bracket;
        [self charon_setExposure:manual.exposureDuration gain:manual.ISO ofCamera:camera];
    }
}

// One photo of a request, on the output's queue or where the previous photo of its bracket was delivered: the request's settings on
// the still image output, the camera's flash and the bracket member's exposure for this photo, the still, and the photo's callbacks.
// `bracket` is this photo's bracket setting (nil for a single photo), `index` its 1-based place in the request and `expected` the
// request's photo count. `first` and `last` mark the request's first and last photo: willBeginCapture comes once, before the first,
// and didFinishCapture once, after the last, which also gives the camera's flash mode back. `completed` runs after the photo's own
// callbacks, so the next photo of a bracket is taken after this one is delivered.
- (void)charon_captureOne:(AVCapturePhotoSettings *)settings bracket:(AVCaptureBracketedStillImageSettings *)bracket
                    index:(NSInteger)index expected:(NSUInteger)expected first:(BOOL)first last:(BOOL)last
               connection:(AVCaptureConnection *)connection delegate:(id<AVCapturePhotoCaptureDelegate>)delegate
                completed:(void (^)(void))completed
{
    // Still image stabilization arrived on AVCaptureStillImageOutput in 7.0; before it the port implements none, and the
    // setting is then what it is on a device without it: kept, and nothing to enable. A request prioritized for speed is not stabilized.
    if ([self respondsToSelector:@selector(setAutomaticallyEnablesStillImageStabilizationWhenAvailable:)])
        self.automaticallyEnablesStillImageStabilizationWhenAvailable =
            settings.autoStillImageStabilizationEnabled && settings.photoQualityPrioritization != AVCapturePhotoQualityPrioritizationSpeed;
    // Every capture takes its own settings' format; without one, a photo settings object asks for a JPEG.
    self.outputSettings = settings.format ?: @{AVVideoCodecKey: AVVideoCodecJPEG};

    NSDictionary *preview = settings.previewPhotoFormat;
    size_t previewLongest = preview ? CharonPreviewLongestSide(preview) : 0;
    NSDictionary *thumbnail = settings.embeddedThumbnailPhotoFormat;
    size_t thumbnailLongest = thumbnail ? CharonThumbnailLongestSide(thumbnail) : 0;
    NSDictionary *metadata = settings.metadata;

    AVCaptureDevice *camera = CharonDeviceForConnection(connection);
    AVCapturePhotoOutput *output = (AVCapturePhotoOutput *)(id)self;
    BOOL willBegin = [delegate respondsToSelector:@selector(captureOutput:willBeginCaptureForResolvedSettings:)];
    BOOL willCapture = [delegate respondsToSelector:@selector(captureOutput:willCapturePhotoForResolvedSettings:)];
    BOOL photoCallback = [delegate respondsToSelector:@selector(captureOutput:didFinishProcessingPhoto:error:)];

    BOOL flashChanged = [self charon_setFlashMode:settings.flashMode ofCamera:camera];

    // What the capture resolves to, known before it starts. The still comes at the dimensions of the video port's
    // format as the session runs it, for every preset, JPEG or 32BGRA, and zoomed (facts, "The resolved settings").
    // With the flash Off, or no flash, it does not fire. Otherwise the camera's flashActive cannot say it before the
    // capture: with the mode just set to Auto it answers NO and turns YES 0.035 s later on an iPhone 4S (facts), and
    // the capture waits for it (below) only up to a bound, whose end says nothing. So the answer is the still's own,
    // bit 0 of its Exif Flash tag, and the settings are resolved when the still comes. Stabilization is the still
    // image output's own answer where it has one, from 7.0.
    AVCaptureInputPort *port = connection.inputPorts.firstObject;
    CMVideoDimensions portDimensions = port.formatDescription ? CMVideoFormatDescriptionGetDimensions(port.formatDescription) : (CMVideoDimensions){0, 0};
    BOOL flashMayFire = camera.hasFlash && camera.flashMode != AVCaptureFlashModeOff;
    BOOL stabilized = [self respondsToSelector:@selector(isStillImageStabilizationActive)] && self.stillImageStabilizationActive;
    int64_t uniqueID = settings.uniqueID;
    AVCaptureResolvedPhotoSettings *(^resolve)(CMVideoDimensions, BOOL, CMVideoDimensions) = ^(CMVideoDimensions photo, BOOL flashEnabled,
                                                                                                 CMVideoDimensions thumbnail) {
        CMVideoDimensions preview = previewLongest ? CharonPreviewDimensions(photo, previewLongest) : (CMVideoDimensions){0, 0};
        AVCaptureResolvedPhotoSettings *resolved = [[AVCaptureResolvedPhotoSettings alloc] initCharonWithUniqueID:uniqueID photoDimensions:photo previewDimensions:preview
                                                                                              embeddedThumbnailDimensions:thumbnail flashEnabled:flashEnabled
                                                                                           stillImageStabilizationEnabled:stabilized];
        [resolved charon_setExpectedPhotoCount:expected];
        return resolved;
    };

    // A port can have no format yet: the first capture after the output joins a running session had none on an iPhone 4S
    // (facts). The dimensions are then the still's own, and the settings are resolved, and willBeginCapture sent, when the
    // still comes, before the other callbacks, so no callback is given dimensions that are not the photo's. The same
    // when the flash may fire, for the flash's answer, and when a thumbnail is asked, for the dimensions of the one
    // embedded: 0x0 when it could not be.
    AVCaptureResolvedPhotoSettings *early = portDimensions.width > 0 && portDimensions.height > 0 && !flashMayFire && !thumbnailLongest
                                                ? resolve(portDimensions, NO, (CMVideoDimensions){0, 0}) : nil;
    // willCapturePhoto comes "just before the photo is taken" (the header), after willBeginCapture. The still image output
    // shows no moment between its call and the still it hands back, so it is sent right before that call; when the
    // settings are resolved from the still, right after willBeginCapture, before didCapturePhoto.
    if (early && first && willBegin)
        [delegate captureOutput:output willBeginCaptureForResolvedSettings:early];
    if (early && willCapture)
        [delegate captureOutput:output willCapturePhotoForResolvedSettings:early];
    // A bracket's photo takes its member's exposure before its still is taken.
    [self charon_applyBracket:bracket toCamera:camera];
    void (^capture)(void) = ^{
        [self captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            CharonAttachMetadata(imageDataSampleBuffer, metadata);
            CMFormatDescriptionRef format = imageDataSampleBuffer ? CMSampleBufferGetFormatDescription(imageDataSampleBuffer) : NULL;
            CMVideoDimensions dimensions = format ? CMVideoFormatDescriptionGetDimensions(format) : (CMVideoDimensions){0, 0};
            // The thumbnail the settings ask for is written into the still before the delegate gets it (the header's rule):
            // the photo delivered is the still with it, the metadata already attached.
            CMVideoDimensions embedded = thumbnailLongest ? CharonPreviewDimensions(dimensions, thumbnailLongest) : (CMVideoDimensions){0, 0};
            CMSampleBufferRef thumbnailed = thumbnailLongest && imageDataSampleBuffer ? CharonCreateSampleWithThumbnail(imageDataSampleBuffer, embedded) : NULL;
            if (thumbnailLongest && imageDataSampleBuffer && !thumbnailed)
                NSLog(@"AVCapturePhotoOutput: the thumbnail asked for could not be embedded in the captured photo; it is delivered without one");
            CMSampleBufferRef photo = thumbnailed ?: imageDataSampleBuffer;
            AVCaptureResolvedPhotoSettings *resolved = early;
            if (!resolved) {
                resolved = resolve(dimensions, flashMayFire && CharonStillFlashFired(imageDataSampleBuffer), thumbnailed ? embedded : (CMVideoDimensions){0, 0});
                if (first && willBegin)
                    [delegate captureOutput:output willBeginCaptureForResolvedSettings:resolved];
                if (willCapture)
                    [delegate captureOutput:output willCapturePhotoForResolvedSettings:resolved];
            }
            if ([delegate respondsToSelector:@selector(captureOutput:didCapturePhotoForResolvedSettings:)])
                [delegate captureOutput:output didCapturePhotoForResolvedSettings:resolved];
            OSType previewFormat = [preview[(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey] unsignedIntValue];
            CMSampleBufferRef previewSample = previewLongest ? CharonCreatePreviewSample(imageDataSampleBuffer, resolved.previewDimensions, previewFormat) : NULL;
            if (previewLongest && imageDataSampleBuffer && !previewSample)
                NSLog(@"AVCapturePhotoOutput: the preview photo asked for could not be made from the captured still; it is delivered without one");
            // The 11.0 callback is the one delivered when the delegate implements it: the photo is an AVCapturePhoto, made for every
            // photo, the error one included (the header: the photo is non nil even with an error). Otherwise the 10.0 callback gets the
            // sample buffers, as on 10.0. (Which of the two a 10.0-11.0 delegate that implements both is given is the port's choice,
            // stated in facts/AVFoundation/AVCapturePhoto11.md.)
            if (photoCallback) {
                AVCapturePhoto *delivered = [[AVCapturePhoto alloc] initCharonWithSampleBuffer:photo previewSampleBuffer:previewSample
                                                                              resolvedSettings:resolved bracketSettings:bracket
                                                                                    photoCount:index embeddedThumbnailPhotoFormat:settings.embeddedThumbnailPhotoFormat
                                                                                    sourceDeviceType:camera.deviceType];
                [delegate captureOutput:output didFinishProcessingPhoto:delivered error:error];
            } else {
                ((void (*)(id, SEL, id, CMSampleBufferRef, CMSampleBufferRef, id, id, id))objc_msgSend)(delegate, sel_registerName("captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:"),
                    output, photo, previewSample, resolved, bracket, error);
            }
            if (previewSample)
                CFRelease(previewSample);
            if (thumbnailed)
                CFRelease(thumbnailed);
            // The scene is monitored for its settings' flash mode again, which the capture's own replaced on the camera, or the
            // camera gets the application's mode back when this was the last capture.
            AVCapturePhotoSettings *monitored = output.photoSettingsForSceneMonitoring;
            if (monitored)
                [self charon_setFlashMode:monitored.flashMode ofCamera:camera];
            if (last) {
                @synchronized (self) {
                    self->_charonCapturesInFlight--;
                }
                [self charon_giveBackCameraFlashMode];
                if ([delegate respondsToSelector:@selector(captureOutput:didFinishCaptureForResolvedSettings:error:)])
                    [delegate captureOutput:output didFinishCaptureForResolvedSettings:resolved error:error];
            }
            if (completed)
                completed();
        }];
    };
    // With the flash mode just changed to one that may fire, the capture waits for flashActive to be judged for it, at
    // most as long as the camera's longest frame: the connection's videoMaxFrameDuration, 1/15 s on an iPhone 4S at the
    // photo preset (facts, "The flash waits for the camera"), or the camera's own from 7.0, where the connection's is
    // deprecated. With the mode unchanged the camera has judged its frames for it already and nothing waits.
    CMTime frame = connection.isVideoMaxFrameDurationSupported ? connection.videoMaxFrameDuration : kCMTimeInvalid;
    if (!CMTIME_IS_NUMERIC(frame) || CMTimeGetSeconds(frame) <= 0)
        frame = camera.activeVideoMaxFrameDuration;
    dispatch_queue_t queue = _charonCaptureQueue;
    if (!flashChanged || !flashMayFire) {
        capture();
    } else if (!CMTIME_IS_NUMERIC(frame) || CMTimeGetSeconds(frame) <= 0) {
        NSLog(@"AVCapturePhotoOutput: the camera answers no frame duration to wait for its flash; the photo is taken at once");
        capture();
    } else {
        dispatch_suspend(queue);
        CharonAfterFlashActiveChanges(camera, CMTimeGetSeconds(frame), ^{
            capture();
            dispatch_resume(queue);
        });
    }
}

// The captures of a request run one after another: a bracket's next photo is taken once the last one is delivered, so the
// still image output never has two captures in flight from one request. The captures run on the output's queue, each with its
// own settings on the still image output and its own flash mode on the camera, which every capture shares: a capture waiting
// for the flash holds back the ones asked after it, which would otherwise put their mode on the camera before it is taken.
// The request counts as one capture in flight until its last photo is delivered.
- (void)capturePhotoWithSettings:(AVCapturePhotoSettings *)settings delegate:(id<AVCapturePhotoCaptureDelegate>)delegate
{
    AVCaptureConnection *connection = [self connectionWithMediaType:AVMediaTypeVideo];
    AVCapturePhotoBracketSettings *bracket = [settings isKindOfClass:[AVCapturePhotoBracketSettings class]] ? (AVCapturePhotoBracketSettings *)settings : nil;
    [self charon_checkSettings:settings connection:connection];
    if (bracket)
        [self charon_checkBracket:bracket];
    // The header's 10.0 rule: a delegate must answer a photo callback. The 11.0 callback (an AVCapturePhoto) or the 10.0 one
    // (the sample buffers) is enough; a delegate with neither would get no photo, silently.
    if (![delegate respondsToSelector:@selector(captureOutput:didFinishProcessingPhoto:error:)] &&
        ![delegate respondsToSelector:@selector(captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:)])
        CharonOutputRaise(@"*** -[AVCapturePhotoOutput capturePhotoWithSettings:delegate:] the delegate must respond to "
                          @"-captureOutput:didFinishProcessingPhoto:error: or -captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:");
    @synchronized (self) {
        [_charonCapturedUniqueIDs addObject:@(settings.uniqueID)];
        _charonCapturesInFlight++;
    }
    // "A defensive copy" of the settings is taken (the header): what the application changes afterwards changes nothing.
    // The copy keeps the bracket's class and its bracketed settings.
    settings = [settings copy];
    AVCaptureDevice *camera = CharonDeviceForConnection(connection);
    NSArray<AVCaptureBracketedStillImageSettings *> *members = bracket ? bracket.bracketedSettings : @[];
    NSUInteger expected = bracket ? members.count : 1;
    // The bias the camera had before the bracket: an auto bracket changes it per photo and gives it back at the end.
    BOOL restoreBias = camera && [members.firstObject isKindOfClass:[AVCaptureAutoExposureBracketedStillImageSettings class]];
    float previousBias = restoreBias ? camera.autoExposureBias : 0;
    // The exposure the camera had before a manual bracket: given back after the last photo, as the bias is.
    BOOL restoreExposure = camera && [members.firstObject isKindOfClass:[AVCaptureManualExposureBracketedStillImageSettings class]];
    CMTime previousDuration = restoreExposure ? camera.exposureDuration : kCMTimeInvalid;
    float previousGain = restoreExposure ? camera.exposureGain : 0;
    __block void (^step)(NSUInteger) = nil;
    step = ^(NSUInteger i) {
        AVCaptureBracketedStillImageSettings *member = bracket ? members[i] : nil;
        BOOL last = i + 1 == expected;
        [self charon_captureOne:settings bracket:member index:(NSInteger)i + 1 expected:expected first:i == 0 last:last
                     connection:connection delegate:delegate completed:^{
            if (!last) {
                step(i + 1);
                return;
            }
            if (restoreBias)
                [self charon_setBias:previousBias ofCamera:camera];
            if (restoreExposure)
                [self charon_setExposure:previousDuration gain:previousGain ofCamera:camera];
            step = nil;
        }];
    };
    dispatch_async(_charonCaptureQueue, ^{
        step(0);
    });
}

@end
