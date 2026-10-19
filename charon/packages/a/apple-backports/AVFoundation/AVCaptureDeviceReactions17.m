// AVCaptureDeviceReactions17.m - the reaction-effects half of the capture-device surface iOS 17 added, and
// the two members iOS 17.2 added to AVCaptureDeviceFormat, as two objects: one release's API each.
//
// WHAT THE PORT ANSWERS, and where every answer comes from. Two oracles, and which one speaks depends on the
// row:
//
//   * this host's own AVFoundation, measured by tests/backports/host/avf-capabilities against this MacBook
//     Pro's built-in camera, which has reactions and background replacement and none of the rest;
//   * the SDK 26.2 header's own words for the case where the hardware does not have the feature, which is
//     this port's case: every device of this port's bands is an iPhone 4S or an iPad 2, and a reaction effect
//     is a camera feature of the devices Apple shipped from 2016 on.
//
// Row by row, with the header line that decides it:
//
//   -availableReactionTypes          empty set: the header (AVCaptureDevice.h:2478, :2481) makes the list the types that can be passed to
//                                    performEffectForReaction, and says it may differ between devices. This camera supports none, so the list
//                                    is empty. The host's camera lists all eight (measured), for the same
//                                    reason it lists them: its camera has the hardware.
//   -canPerformReactionEffects       NO: the header (:2471) answers YES only when reaction resources exist on the device instance.
//   -reactionEffectsInProgress       an empty array: nothing can start a reaction, so none is running.
//   +reactionEffectsEnabled          the DOCUMENTED rule, read out of the application: on iOS, reaction effects are on by default for
//                                    video conferencing apps (those with voip among their background modes), and other apps may opt in through
//                                    NSCameraReactionEffectsEnabled (:2448-2450). The host answers YES because macOS's own rule turns them on for all apps (:2447),
//                                    which is a different platform's rule and not this one's.
//   +reactionEffectGesturesEnabled   the DOCUMENTED default (:2461) has gesture detection on, which iOS 17.4 lets an application change with
//                                    NSCameraReactionEffectGesturesEnabledDefault in its Info.plist. The
//                                    host answers NO because it reflects this Mac's Control Center Gestures
//                                    setting (:2458); a release with no such setting stays at its default.
//   +systemPreferredCamera           the user's choice when there is one, and the release's own best camera
//                                    otherwise. The header (AVCaptureDevice.h:674) takes userPreferredCamera into account along with camera suspension and Apple cameras arriving, and gives a present device, or nil when there is none.
//                                    suspension and Apple cameras arriving, and gives a present device, or nil when there is none.
//                                    The "other factors" this release has are the ones its own
//                                    +defaultDeviceWithMediaType: answers, and nothing invented: the devices of
//                                    this port's bands have a camera on each side and the release's answer for
//                                    AVMediaTypeVideo, the release's built-in capture camera (AVCaptureDevice.h:120), which is the one on the back. The
//                                    call, not a position, is what is written here, so the port cannot drift
//                                    from the release's own choice.
//   +userPreferredCamera             the camera an application chose, kept across launches, and only ever a
//                                    camera that is present. The rules, all from the header (AVCaptureDevice.h:661-663): setting it lets an application keep
//                                    the user's choice across launches, a short history of choices is kept, a read gives a present device or nil when there is none, and setting nil changes nothing.
//                                    So: the most recent entry of the history that is in the device list NOW; nil
//                                    while the history is empty (measured on the host, which answers nil until an
//                                    application sets one); the release's own best camera once the history is
//                                    exhausted, which is the same "next best choice" one step further and is nil
//                                    itself when the device has no camera at all; and a nil set adds nothing, so
//                                    the choice survives it (measured on the host: after setting nil the getter
//                                    still answers the camera it was given).
//   -performEffectForReaction:        raises. The header (:2496) requires the reactionType to be one of the availableReactionTypes, or it throws: the
//                                    list is empty, so every type is one that must not be passed. The
//                                    header names no exception for it, and the port raises
//                                    NSInvalidArgumentException - the name the two refusals this host's own
//                                    class raises for unsupported arguments use (measured:
//                                    "*** -[AVCaptureDALDevice setAutoVideoFrameRateEnabled:] Not supported"
//                                    and "*** -[AVCaptureDeviceInput setMultichannelAudioMode:] Not supported").
//                                    The header's other half of the rule is that a reaction asked for while canPerformReactionEffects is NO is ignored (:2496), and it is what a
//                                    type that IS available would get; no type is available here.
//   Format -reactionEffectsSupported NO, the same hardware answer for a format. The host's camera answers
//                                    YES for all seven of its formats (measured).
//   Format -videoFrameRateRangeForReactionEffectsInProgress
//                                    nil, the header's own nullability for a format that cannot run a
//                                    reaction. Every format of the host's camera reports
//                                    reactionEffectsSupported YES and a 15-30 AVFrameRateRange (measured),
//                                    so the NO case cannot be read off this host and the pairing comes from
//                                    the header.
//   Format -supportedVideoZoomRangesForDepthDataDelivery
//                                    an empty array, and the host's own camera answers an empty array here
//                                    too (measured): no zoom range of this camera feeds depth delivery.
//   Format -zoomFactorsOutsideOfVideoZoomRangesForDepthDeliverySupported
//                                    NO, measured NO on the host's own camera as well.
//
// THE BANDS. Both objects are categories on classes the release carries, so they export no symbol of their
// own and band() keeps them in every band from the floor up - which is what every category in this package
// does, and what the port wants: from 17.0 up, the port's answers are the ones for hardware this port's
// devices do not have, and the release's own would be the ones for hardware they do.
#import "CharonAVCaptureDeviceReactions17.h"

// THE PREFERRED-CAMERA PAIR. The choice an application made is kept in the application's own NSUserDefaults,
// under one key, as the identifiers of the devices that were set, most recent first.
//
// The key and why that store, measured rather than assumed:
//   * NSUserDefaults is the only store a program can use to keep a value "across app launches and reboots",
//     which is what the header says this property is for (:661). The release's own store is the system's and
//     is not in the application's domain - MEASURED on this host: setting +userPreferredCamera adds 0 keys to
//     the bundle's own defaults and writes nothing at all into its persistent domain. So the port keeps the
//     choice where it can, and says which key, rather than pretending to reach the system's.
//   * identifiers, not devices: an AVCaptureDevice does not outlive the process that made it, and the header's
//     promise is across launches. -uniqueID is the release's own name for a device across the process boundary.
//   * a short history, not one value, because the header keeps a short history (:662). Three entries is the
//     depth here: enough for a most-recent entry that has gone missing to have a next choice to report, and bounded.
#define CHARON_CAPTURE_USER_PREFERRED_HISTORY_KEY @"CharonCaptureUserPreferredCameraHistory"
#define CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH 3

// The history as it stands, most recent first, deduplicated and never longer than the depth. Read out of the
// application's defaults every time rather than kept in a static: the getter has to answer what another launch
// left behind, and one process's static is not what survives.
static NSArray<NSString *> *charon_user_preferred_history(void)
{
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:CHARON_CAPTURE_USER_PREFERRED_HISTORY_KEY];
    if (![stored isKindOfClass:[NSArray class]])
        return [NSArray array];
    NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
    for (id entry in (NSArray *)stored) {
        if ([entry isKindOfClass:[NSString class]] && [entry length] && ![identifiers containsObject:entry])
            [identifiers addObject:entry];
        if (identifiers.count >= CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)
            break;
    }
    return identifiers;
}

// The camera an application chose. A class property, so one value for the process, and it is not kept in an ivar
// for the same reason: the release's class cannot be given one by a category, and a value in a static would not
// survive the next launch, which is the half of the header's promise this row is about.
@implementation AVCaptureDevice (CharonCaptureDeviceReactions17)

- (NSSet<AVCaptureReactionType> *)availableReactionTypes
{
    return [NSSet set];
}

- (BOOL)canPerformReactionEffects
{
    return NO;
}

- (NSArray<AVCaptureReactionEffectState *> *)reactionEffectsInProgress
{
    return [NSArray array];
}

// The header's iOS rule, read out of the application rather than answered with a constant: YES when the
// application is a video conferencing one (voip among its UIBackgroundModes) or has opted in with
// NSCameraReactionEffectsEnabled. Both are the application's own Info.plist, which is where the header says
// they live, and both are read through NSBundle - the public way to read them.
+ (BOOL)reactionEffectsEnabled
{
    NSBundle *bundle = [NSBundle mainBundle];
    id opted_in = [bundle objectForInfoDictionaryKey:@"NSCameraReactionEffectsEnabled"];
    if ([opted_in isKindOfClass:[NSNumber class]] && [opted_in boolValue]) {
        return YES;
    }
    id modes = [bundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    if ([modes isKindOfClass:[NSArray class]] && [modes containsObject:@"voip"]) {
        return YES;
    }
    return NO;
}

// The header's documented default is enabled; an application may set the default from 17.4 on with
// NSCameraReactionEffectGesturesEnabledDefault, and until the user changes it in Control Center - a setting
// this release does not have - the value stays where it started.
+ (BOOL)reactionEffectGesturesEnabled
{
    id setting = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSCameraReactionEffectGesturesEnabledDefault"];
    if ([setting isKindOfClass:[NSNumber class]]) {
        return [setting boolValue];
    }
    return YES;
}

+ (AVCaptureDevice *)systemPreferredCamera
{
    // The header (:674) takes userPreferredCamera along with other factors, and gives a present device or nil: the user's choice first, and otherwise the release's own
    // best camera, which is what +defaultDeviceWithMediaType: answers and what it answers nil for on a device
    // with no camera. The choice is asked for through its own property rather than through the history, so the
    // "next best choice" the two properties share is one piece of code.
    return [AVCaptureDevice userPreferredCamera] ?: [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

+ (AVCaptureDevice *)userPreferredCamera
{
    NSArray<NSString *> *history = charon_user_preferred_history();
    NSArray<AVCaptureDevice *> *present = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    // The header (:662-663) keeps a short history, so a preferred camera that has gone missing gives the next best choice, and a present device always: the most recent entry of the history that is in the device list now, and never an
    // entry that is not.
    for (NSString *identifier in history) {
        for (AVCaptureDevice *device in present) {
            if ([device.uniqueID isEqualToString:identifier])
                return device;
        }
    }
    // Nothing was ever chosen. The measured host answer for a property that has not been set is nil, with a
    // camera present (:663 reserves nil for a device with no camera at all, and a choice that was never made is
    // not a camera).
    if (history.count == 0)
        return nil;
    // The history is exhausted and the device has a camera: the same "next best choice" one step further is the
    // release's own best present one, and that call answers nil itself when there is no camera (:663).
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

+ (void)setUserPreferredCamera:(AVCaptureDevice *)userPreferredCamera
{
    // "Setting the property to nil has no effect" (:663), measured on the host: after a nil the getter still
    // answers the camera that was set before it. A nil therefore adds nothing to the history, rather than
    // clearing it.
    if (!userPreferredCamera)
        return;
    NSString *identifier = userPreferredCamera.uniqueID;
    if (![identifier length])
        return;
    NSMutableArray<NSString *> *history = [charon_user_preferred_history() mutableCopy];
    [history removeObject:identifier];
    [history insertObject:identifier atIndex:0];
    if (history.count > CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)
        [history removeObjectsInRange:NSMakeRange(CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH,
                                                  history.count - CHARON_CAPTURE_USER_PREFERRED_HISTORY_DEPTH)];
    [[NSUserDefaults standardUserDefaults] setObject:[history copy]
                                              forKey:CHARON_CAPTURE_USER_PREFERRED_HISTORY_KEY];
}

- (void)performEffectForReaction:(AVCaptureReactionType)reactionType
{
    // The header's rule: the type must be one -availableReactionTypes lists. That list is empty, so every
    // type is one the header says raises, and a reaction with canPerformReactionEffects NO is ignored.
    if (![[self availableReactionTypes] containsObject:reactionType]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"-%@ is not one of the reaction types this AVCaptureDevice can perform (availableReactionTypes "
                           @"is empty: this camera has no reaction effects), and -performEffectForReaction: throws "
                           @"for any other type", NSStringFromSelector(_cmd)];
    }
}

@end

@implementation AVCaptureDeviceFormat (CharonCaptureDeviceFormatReactions17)

- (BOOL)reactionEffectsSupported
{
    return NO;
}

- (AVFrameRateRange *)videoFrameRateRangeForReactionEffectsInProgress
{
    return nil;
}

@end