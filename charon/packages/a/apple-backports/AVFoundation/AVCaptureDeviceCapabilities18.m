// AVCaptureDeviceCapabilities18.m - the fifteen members AVCaptureDevice, AVCaptureDeviceFormat and
// AVCaptureDeviceInput gained in iOS 18, in one object, with the two refusals the header itself names.
//
// ONE OBJECT, and that is the placement rule rather than a preference: every member below is 18.0 in the
// header and in the ledger's classification of the caches, so one object holds API of one release.
// modules/apple/backports.lua's band() keeps an object in a band when that band's release exports none of
// its symbols, and this object exports none of its own - it is three categories on classes every release
// already carries - so it is kept in every band from the floor up, which is what every other capture-device
// category in this package does (AVCaptureDeviceReactions17.m says so for the same three classes). At 18.0
// and above the release's own classes would answer instead if the release exported these selectors; it does
// not, which is why they are rows at all (measured: the 18.0 arm64e cache's own Objective-C metadata carries
// none of the fifteen - facts/AVFoundation/CaptureDeviceCapabilities18.md, "What the releases carry").
//
// THE ORACLE for every answer below is one of two, and which one speaks depends on the row:
//
//   * THIS HOST'S OWN AVFoundation, against this MacBook Pro's camera and its microphone, measured by
//     tests/backports/host/avf-capabilities. That camera has Background Replacement and one microphone that
//     answers NO for wind noise removal, so several rows are the same answer on both sides and the harness
//     compares them;
//   * the SDK 26.2 header's own words for the case where the hardware does not have the feature, which is this
//     port's case: every device of this port's bands is an iPhone 4S or an iPad 2, with a camera on each
//     side and ONE microphone (measured on both, facts/AVFoundation/AVCaptureDeviceDiscovery.md, "What the
//     hardware has"), and Background Replacement, spatial video, auto video frame rate and ambisonics are
//     features of hardware Apple shipped years later.
//
// Row by row, with the line of the header that decides it. Line numbers are 26.2's own.
//
//   -isAutoVideoFrameRateEnabled   the value the last accepted -setAutoVideoFrameRateEnabled: was given,
//                                  defaulting to false, and it resets to that default when the active format changes (:399).
//   -setAutoVideoFrameRateEnabled:
//                                  the header's own refusal, by its own rule: setting it throws NSInvalidArgumentException when the active format's
//                                  autoVideoFrameRateSupported is false (:399). Every format of this
//                                  port answers NO for that (below), so every set raises here - the rule,
//                                  not a constant refusal, and the port keeps the value for a format that
//                                  supported it. Apple's own reason string, measured on this host:
//                                  "*** -[AVCaptureDALDevice setAutoVideoFrameRateEnabled:] Not supported -
//                                  use -[AVCaptureDeviceFormat autoVideoFrameRateSupported]". The tail is
//                                  Apple's character for character; the class it names is not, because
//                                  AVCaptureDALDevice is a private class of Apple's device-access layer that
//                                  this port does not have, while the setter below belongs to
//                                  AVCaptureDevice - the class the port does have.
//   +isBackgroundReplacementEnabled
//                                  NO: the header (:2521) describes a class property for whether the user has enabled Background Replacement for this application. There is no
//                                  such user setting on this release - no feature to enable it for, no
//                                  Settings switch and no Control Center - so there is no choice for it to
//                                  report. The host answers 0 here as well (measured).
//   -isBackgroundReplacementActive
//                                  NO: the header (:2524) reports whether Background Replacement is active on one device. Nothing can start it, for the row
//                                  above. The host answers 0 here too (measured).
//   -displayVideoZoomFactorMultiplier
//                                  1.0: the header (:1987) says a system user interface may display the zoom factor in a form that differs from videoZoomFactor
//                                  by a fixed ratio. The ratio is there for a system UI to display through,
//                                  and this release has none - the header's own examples are "the macOS
//                                  Video Effects Menu" - so the factor is displayed as itself and the ratio
//                                  is the identity. (This Mac's own is 0.5, measured: its menu shows half
//                                  the capture value.)
//   -spatialCaptureDiscomfortReasons
//                                  an empty set: the header (:2673) describes conditions under which a spatial capture is comfortable to watch. This hardware
//                                  cannot capture spatially at all - every format answers NO for
//                                  -isSpatialVideoCaptureSupported below - so no scene is amenable. The
//                                  host answers an empty set here as well (measured).
//   Format -isAutoVideoFrameRateSupported
//                                  NO: the format's own property for auto video frame rate support, described in the header
//                                  (:3508). The feature is the device lowering its frame rate under low
//                                  light; this hardware has no such mode. Measured on the host: 0 for all
//                                  seven of its formats.
//   Format -isBackgroundReplacementSupported
//                                  NO: the header (:3736) answers YES where the format supports Background Replacement, and no format of this hardware does. Measured on
//                                  the host: 1 for all seven of its formats, which is the hardware.
//   Format -isSpatialVideoCaptureSupported
//                                  NO: the format's property (:3553) says whether it can record spatial video into a file. Two lenses recording a depth map are what it takes;
//                                  this hardware has one lens per camera. Measured on the host: 0.
//   Format -systemRecommendedExposureBiasRange
//                                  nil when no recommendation is available (:3309). A recommendation is a system's own range for its own exposure
//                                  controls, and this release has none - AVCaptureSystemExposureBiasSlider
//                                  arrived with iOS 18 and the class is not a row this port carries. The
//                                  host answers nil here too (measured).
//   Format -systemRecommendedVideoZoomRange
//                                  nil, by the same sentence of the same paragraph (:3277), and for the same
//                                  reason: AVCaptureSystemZoomSlider is iOS 18's. Measured on the host: nil.
//   Format -videoFrameRateRangeForBackgroundReplacement
//                                  nil, the header's own answer for a format that cannot run the feature (:3746). Measured on the host: a range, for all
//                                  seven formats, because its camera supports Background Replacement.
//   -isMultichannelAudioModeSupported:
//                                  YES for AVCaptureMultichannelAudioModeNone and NO for the other two, by
//                                  the header's own reading of what the modes are (:357-362): None means no multichannel audio, which is what a single microphone records, and
//                                  Stereo and first-order ambisonics are two and four microphones' worth of
//                                  audio respectively, and this device has one. Measured on this host, whose
//                                  microphone is a single one as well: 1, 0, 0 - the port and the host agree
//                                  on all three modes.
//   -multichannelAudioMode          the value, defaulting to AVCaptureMultichannelAudioModeNone, which the header (:395) describes as the
//                                  default single channel recording. Measured on the host: 0.
//   -setMultichannelAudioMode:      the header's own rule, by which the value the caller may set is exactly
//                                  the set -isMultichannelAudioModeSupported answers YES for. The header (:381) allows a value only when that method returns YES for it. So None is
//                                  accepted and kept - measured on this host, which does the same - and
//                                  Stereo, first-order ambisonics, an out-of-range number and a negative one
//                                  all raise NSInvalidArgumentException with Apple's own reason, measured on
//                                  this host as "*** -[AVCaptureDeviceInput setMultichannelAudioMode:] Not
//                                  supported" (sent to an input inside a session, the host names its own
//                                  internal class there, AVCaptureDeviceInput_Tundra; this port has one
//                                  class of this name, the one the header declares the member on).
//   -isWindNoiseRemovalSupported    NO: the header (:405) answers by whether the device supports wind noise removal.
//                                  Measured on this host, whose built-in microphone answers NO as well.
//   -isWindNoiseRemovalEnabled      the value the caller set, defaulting to NO, which is what Apple's own
//                                  setter does with a device that does not support the feature - measured on
//                                  this host: set YES answers YES afterwards even though
//                                  isWindNoiseRemovalSupported is 0, and set NO answers NO again. Nothing on
//                                  this release acts on it: the header (:415) says the wind filter works when the input's multichannelAudioMode is set to
//                                  any mode except AVCaptureMultichannelAudioModeNone, and
//                                  this input cannot be set to any other value (above).
#import "CharonAVCaptureDeviceCapabilities18.h"
#import <objc/runtime.h>

// The values the port keeps per object. Three keys, each used by one pair of accessors, and each a static
// so no other object in this library has to link against a symbol of this one. An associated object is the
// only place a category can keep one: the classes here belong to the release, and a category cannot add an
// ivar to them.
static const char charon_auto_video_frame_rate_key;
static const char charon_multichannel_audio_mode_key;
static const char charon_wind_noise_removal_key;

// The value a key holds, or the given default when nothing has been set on this object. The default is the
// header's own for each of the three: false for the frame-rate flag, AVCaptureMultichannelAudioModeNone for the
// mode, NO for the wind-noise flag - and passing it here keeps each of those in the accessor that reads it.
static id charon_capture_value(id object, const char *key, id fallback)
{
    id stored = objc_getAssociatedObject(object, key);
    return stored ? stored : fallback;
}

@implementation AVCaptureDevice (CharonCaptureDeviceCapabilities18)

- (BOOL)isAutoVideoFrameRateEnabled
{
    return [charon_capture_value(self, &charon_auto_video_frame_rate_key, @NO) boolValue];
}

- (void)setAutoVideoFrameRateEnabled:(BOOL)enabled
{
    // The header's rule, quoted above: the active format decides whether this value may be set at all.
    // -activeFormat is the release's own member, and the answer is asked of it through an id on purpose: the
    // declaration of that property is in CharonAVCaptureDeviceCapabilities18.h, which
    // tests/backports/host/avf-capabilities does not compile this copy against (it drops the port's own
    // header, so the copy cannot replace Apple's own members in that process), and a message send to an id
    // needs no declaration. It is the same IMP either way.
    id format = self.activeFormat;
    if (![format isAutoVideoFrameRateSupported]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVCaptureDevice %@] Not supported - use "
                           @"-[AVCaptureDeviceFormat autoVideoFrameRateSupported]",
                           NSStringFromSelector(_cmd)];
        return;
    }
    objc_setAssociatedObject(self, &charon_auto_video_frame_rate_key, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isBackgroundReplacementActive
{
    return NO;
}

+ (BOOL)isBackgroundReplacementEnabled
{
    return NO;
}

- (CGFloat)displayVideoZoomFactorMultiplier
{
    return 1.0;
}

- (NSSet<AVSpatialCaptureDiscomfortReason> *)spatialCaptureDiscomfortReasons
{
    return [NSSet set];
}

@end

@implementation AVCaptureDeviceFormat (CharonCaptureDeviceFormatCapabilities18)

- (BOOL)isAutoVideoFrameRateSupported
{
    return NO;
}

- (BOOL)isBackgroundReplacementSupported
{
    return NO;
}

- (BOOL)isSpatialVideoCaptureSupported
{
    return NO;
}

- (AVExposureBiasRange *)systemRecommendedExposureBiasRange
{
    return nil;
}

- (AVZoomRange *)systemRecommendedVideoZoomRange
{
    return nil;
}

- (AVFrameRateRange *)videoFrameRateRangeForBackgroundReplacement
{
    return nil;
}

@end

@implementation AVCaptureDeviceInput (CharonCaptureDeviceInputCapabilities18)

- (BOOL)isMultichannelAudioModeSupported:(AVCaptureMultichannelAudioMode)multichannelAudioMode
{
    // The header's reading of the three modes, quoted above. A number that is not one of them is a mode
    // this device does not support, which is also what the host answers for 3 and for -1 (measured).
    return multichannelAudioMode == AVCaptureMultichannelAudioModeNone;
}

- (AVCaptureMultichannelAudioMode)multichannelAudioMode
{
    return (AVCaptureMultichannelAudioMode)[charon_capture_value(self, &charon_multichannel_audio_mode_key,
                                                                @(AVCaptureMultichannelAudioModeNone)) integerValue];
}

- (void)setMultichannelAudioMode:(AVCaptureMultichannelAudioMode)multichannelAudioMode
{
    if (![self isMultichannelAudioModeSupported:multichannelAudioMode]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVCaptureDeviceInput %@] Not supported", NSStringFromSelector(_cmd)];
        return;
    }
    objc_setAssociatedObject(self, &charon_multichannel_audio_mode_key, @(multichannelAudioMode),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isWindNoiseRemovalSupported
{
    return NO;
}

- (BOOL)isWindNoiseRemovalEnabled
{
    return [charon_capture_value(self, &charon_wind_noise_removal_key, @NO) boolValue];
}

- (void)setWindNoiseRemovalEnabled:(BOOL)windNoiseRemovalEnabled
{
    // No refusal here, and that is the measured answer rather than a decision: Apple's own setter keeps what
    // it was given on an input whose isWindNoiseRemovalSupported is 0 (measured on this host, both spellings
    // and both values). What the header says the value is for cannot happen on this release anyway, because
    // wind noise removal needs a multichannel mode this input cannot be set to.
    objc_setAssociatedObject(self, &charon_wind_noise_removal_key, @(windNoiseRemovalEnabled),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end