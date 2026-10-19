// AVCaptureDeviceCinematicVideo26.m - the ten members of iOS 26's Cinematic Video capture, in one object.
//
// ONE OBJECT, and one release: every member below is 26.0 in the header, and the classes are the same three
// the two slices above it in this folder carry: seven properties and three methods. It is three categories on
// classes every release carries, so it
// exports no symbol of its own and band() keeps it in every band from the floor up, which is what every other
// capture-device category in this package does.
//
// THE ORACLE, and it is this Mac's own AVFoundation against its camera and a video input, measured by
// tests/backports/host/avf-capabilities. What it answered, and what it did not:
//
//   * the host's own framework carries NO -cinematicVideoCaptureSceneMonitoringStatuses at all - measured, and
//     so that one row has no host column: the host is macOS 27 and its AVCaptureDevice does not answer the
//     selector. The port's answer for it is the header's own (an empty set, below) and the harness says so in
//     the run rather than reading a host value that is not there.
//   * every other row the host answers, and its answers are the header's own documented answers for hardware
//     that cannot do Cinematic Video: 0 for both support flags, 1.0 and 1.0 for the two zoom factors, nil for
//     the frame rate range - for all seven of its formats, measured.
//
// Cinematic Video is a feature of hardware Apple shipped years later: it renders a controllable simulated
// depth of field out of two cameras and a depth map, with focus transitions between them. A single-lens iPhone
// 4S or iPad 2 has neither the second lens nor the depth map, and the release's own capture session has no
// member for any of it - 6.1.3's AVCaptureDevice, AVCaptureDeviceFormat and AVCaptureDeviceInput own none of
// these seven selectors (tools/corpus/objc-inventory.lua over the 6.1.3 armv7 cache), so there is nothing for
// this object to stand on but the header's own words. Row by row:
//
//   -cinematicVideoCaptureSceneMonitoringStatuses
//                                  an empty set. The header (AVCaptureDevice.h:2690-2692) describes them as prompts for the user to
//                                  reframe a scene so that Cinematic Video plays back better. The statuses
//                                  report whether the SCENE suits the feature, and there is no feature here to
//                                  suit, so no status applies - the same shape as the spatial-capture
//                                  discomfort reasons in the 18.0 slice. The type's one constant is a 26.0
//                                  row of its own (code+lift) and is not carried, so nothing a caller can name
//                                  is ever in the set.
//   Format -isCinematicVideoCaptureSupported
//                                  NO: the header (:3784) makes the property true only where the format can render an adjustable, synthetic depth
//                                  of field and focus transitions. Measured on the host: 0 for
//                                  all seven of its formats.
//   Format -videoMinZoomFactorForCinematicVideo / -videoMaxZoomFactorForCinematicVideo
//                                  1.0, which is the header's own answer for a format that cannot do the feature (:3805, :3810), and 1.0 is also this port's own
//                                  zoom floor: the release's minimum video zoom factor is 1 and its own
//                                  scale-and-crop limit is above it (facts/AVFoundation/Release11.md,
//                                  "The two zoom rows"). Measured on the host: 1 and 1, for all seven formats.
//   Format -videoFrameRateRangeForCinematicVideo
//                                  nil, the header's own answer for the same case (:3815).
//                                  Measured on the host: nil.
//   -isCinematicVideoCaptureSupported (on the input)
//                                  whatever the device's ACTIVE FORMAT says, because the header's rule is
//                                  about the session's configuration: the header (AVCaptureInput.h:427) says the property is true when that configuration
//                                  allows Cinematic Video capture, and it may change when cameras or formats are switched.
//                                  A configuration can only allow what a format supports, so the format is
//                                  what this asks - the release's own -device and -activeFormat, then this
//                                  port's format member. With no active format (which is what 6.1.3's release
//                                  answers outside a running session, measured on a device,
//                                  facts/AVFoundation/Release11.md) there is no configuration and the answer
//                                  is NO. Measured on the host: 0.
//   -isCinematicVideoCaptureEnabled
//                                  the value the caller set, false until then - "Default is false" (:433).
//   -setCinematicVideoCaptureEnabled:
//                                  the header (:436) allows true only where cinematicVideoCaptureSupported is true, so YES refuses and NO is kept. Apple's own reason, measured on
//                                  this host: "*** -[AVCaptureDeviceInput setCinematicVideoCaptureEnabled:] Not
//                                  supported - use isCinematicVideoCaptureSupported", which the port raises
//                                  unchanged - here the class in Apple's string is the one the header declares
//                                  the member on, so there is nothing to swap.
#import "CharonAVCaptureDeviceCinematicVideo26.h"
#import <objc/runtime.h>

// Where the port keeps the one value this family has to keep. An associated object is the only place a category
// can keep one: the class belongs to the release and a category cannot add an ivar to it.
static const char charon_cinematic_video_enabled_key;

// The three focus methods, and the one refusal they share. Each names a point of interest in the device's own
// normalized coordinate space ([0,1], the coordinate space the 16.4 header gives -focusPointOfInterest) and a
// focus mode, and none of them can do anything on a device whose format does not support Cinematic Video:
// Apple's own refusal for all three says so in Apple's own words, measured on this host -
// "*** -[AVCaptureDALDevice setCinematicVideoFixedFocusAtPoint:focusMode:] Not supported - use
// activeFormat.isCinematicVideoCaptureSupported" and the same for the other two - and it names the format
// member the three need. The tail after the class name is what the port raises; the class is not copied,
// because AVCaptureDALDevice is a private class of Apple's device-access layer and these methods belong to
// AVCaptureDevice.
//
// The receiver is asked through an id, for the reason the input's support flag above gives.
static void charon_cinematic_focus_refused(SEL selector)
{
    [NSException raise:NSInvalidArgumentException
                format:@"*** -[AVCaptureDevice %@] Not supported - use"
                       @" activeFormat.isCinematicVideoCaptureSupported",
                       NSStringFromSelector(selector)];
}

@implementation AVCaptureDevice (CharonCaptureDeviceCinematicVideo26)

- (NSSet<AVCaptureSceneMonitoringStatus> *)cinematicVideoCaptureSceneMonitoringStatuses
{
    return [NSSet set];
}

// The format member these three focus methods ask: this port's own AVCaptureDeviceFormat member, reached
// through the release's own -activeFormat, and NO where there is no active format (which is what 6.1.3 answers
// outside a running session). It is a macro and not a method because a method would put a selector in this
// library's metadata that no SDK header declares, which rule R4 and the registry check both notice. The
// receivers are id, for the reason the input's support flag below gives, and each method that uses it carries
// API_AVAILABLE(ios(26.0)) on its definition, which is what covers the send (the same shape
// AVCaptureControls18.m uses for a definition whose signature names an 18.0 type).
#define CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(device) \
    ({ id format = [(device) activeFormat]; format ? [format isCinematicVideoCaptureSupported] : NO; })

- (void)setCinematicVideoTrackingFocusWithDetectedObjectID:(NSInteger)detectedObjectID
                                                focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        charon_cinematic_focus_refused(_cmd);
        return;
    }
}

- (void)setCinematicVideoTrackingFocusAtPoint:(CGPoint)point
                                    focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        charon_cinematic_focus_refused(_cmd);
        return;
    }
}

- (void)setCinematicVideoFixedFocusAtPoint:(CGPoint)point
                                 focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0))
{
    if (!CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self)) {
        charon_cinematic_focus_refused(_cmd);
        return;
    }
}

@end

@implementation AVCaptureDeviceFormat (CharonCaptureDeviceFormatCinematicVideo26)

- (BOOL)isCinematicVideoCaptureSupported
{
    return NO;
}

- (CGFloat)videoMinZoomFactorForCinematicVideo
{
    return 1.0;
}

- (CGFloat)videoMaxZoomFactorForCinematicVideo
{
    return 1.0;
}

- (AVFrameRateRange *)videoFrameRateRangeForCinematicVideo
{
    return nil;
}

@end

@implementation AVCaptureDeviceInput (CharonCaptureDeviceInputCinematicVideo26)

- (BOOL)isCinematicVideoCaptureSupported API_AVAILABLE(ios(26.0))
{
    // The header's rule is about the session's configuration, so the answer is the active format's: the
    // release's own -device and -activeFormat, then this port's format member. An input of a device with no
    // active format has no configuration, and the answer is NO.
    //
    // The receiver is asked through an id, for the reason AVCaptureDeviceCapabilities18.m gives: the
    // declaration of -isCinematicVideoCaptureSupported is in CharonAVCaptureDeviceCinematicVideo26.h, which
    // the host harness does not compile its copy against, and a message send to an id needs no declaration.
    return CHARON_CINEMATIC_VIDEO_FORMAT_SUPPORTS(self.device);
}

- (BOOL)isCinematicVideoCaptureEnabled
{
    id stored = objc_getAssociatedObject(self, &charon_cinematic_video_enabled_key);
    return stored ? [stored boolValue] : NO;
}

- (void)setCinematicVideoCaptureEnabled:(BOOL)cinematicVideoCaptureEnabled
{
    // "You may only set this property to true if cinematicVideoCaptureSupported is true" (AVCaptureInput.h:436).
    // Setting false is always allowed, which is what makes this a value and not a refusal.
    if (cinematicVideoCaptureEnabled && !self.isCinematicVideoCaptureSupported) {
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVCaptureDeviceInput %@] Not supported - use"
                           @" isCinematicVideoCaptureSupported",
                           NSStringFromSelector(_cmd)];
        return;
    }
    objc_setAssociatedObject(self, &charon_cinematic_video_enabled_key, @(cinematicVideoCaptureEnabled),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end