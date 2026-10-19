// CharonAVCaptureDeviceReactions17.h - the reaction-effects surface AVCaptureDevice and AVCaptureDeviceFormat
// gained in iOS 17, and the two depth-zoom members of AVCaptureDeviceFormat in iOS 17.2. SDK 16.4 declares
// none of it: its AVCaptureDevice.h has no availableReactionTypes, no canPerformReactionEffects, no
// performEffectForReaction: and its AVCaptureReactions.h does not exist, so every class, typedef and member
// below is the port's own to declare. This is what this package's CharonAVMetrics18.h and
// CharonAVCaptureControls18.h do for surface that arrived after the SDK the toolchain resolves.
//
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureDevice.h:2437-2499
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureReactions.h:17-22
//   iPhoneOS26.2.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureDeviceFormat.h
//
// The declarations are the 26.2 interface's, written for this port, with ONE change, stated here rather than made silently: every
// `, visionos(<version>)` and `, watchos(<version>)` is dropped, because SDK 16.4's availability.h does not
// know those words and expanding one there is `error: expected ','` on the line after the macro's own
// argument. Nothing is lost: the annotations mark platforms this port does not build for.
//
// The names the port adds beyond the SDK are listed in the delivery for rule R4.
#if !__has_include(<AVFCore/AVCaptureReactions.h>)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
// AVCaptureDeviceFormat is declared in the 16.4 SDK's AVCaptureDevice.h and nowhere else, which is
// why there is no import of its own for it here.
#import <AVFoundation/AVCaptureDevice.h>

NS_ASSUME_NONNULL_BEGIN

/// The type of a reaction, as AVFoundation/AVFoundationGlobals180.m already carries its eight values.
typedef NSString *AVCaptureReactionType NS_TYPED_ENUM;

/// One reaction running on the video stream. The 16.4 SDK declares neither this class nor its members, and
/// the port does not carry it: nothing on this release can start a reaction (see
/// AVCaptureDeviceReactions17.m), so no instance of it is ever made and a forward declaration is what a
/// caller needs to hold what -reactionEffectsInProgress hands back.
@class AVCaptureReactionEffectState;

/// A zoom range a device format offers, named in AVCaptureDeviceFormat's depth-delivery members. The 16.4
/// SDK does not declare AVZoomRange either; its own rows are a family of their own.
@class AVZoomRange;

@interface AVCaptureDevice (CharonCaptureDeviceReactions17)

@property(nonatomic, readonly) NSSet<AVCaptureReactionType> *availableReactionTypes;
@property(nonatomic, readonly) BOOL canPerformReactionEffects;
@property(nonatomic, readonly) NSArray<AVCaptureReactionEffectState *> *reactionEffectsInProgress;
@property(class, readonly) BOOL reactionEffectsEnabled;
@property(class, readonly) BOOL reactionEffectGesturesEnabled;
@property(class, readonly, nullable) AVCaptureDevice *systemPreferredCamera;
@property(class, readwrite, nullable) AVCaptureDevice *userPreferredCamera;
- (void)performEffectForReaction:(AVCaptureReactionType)reactionType NS_SWIFT_NAME(performEffect(for:));

@end

@interface AVCaptureDeviceFormat (CharonCaptureDeviceFormatReactions17)

@property(nonatomic, readonly) BOOL reactionEffectsSupported;
@property(nonatomic, readonly, nullable) AVFrameRateRange *videoFrameRateRangeForReactionEffectsInProgress;

@end

// iOS 17.2's own two members, in a category of their own because they are a different release's API and
// AVCaptureDeviceFormatDepthZoom17.m carries them: a category that declared them next to the 17.0 ones
// would ask that object for two methods it does not implement, which clang says out loud
// (-Wobjc-property-implementation, "property declared here").
@interface AVCaptureDeviceFormat (CharonCaptureDeviceFormatDepthZoom17)

@property(nonatomic, readonly) NSArray<AVZoomRange *> *supportedVideoZoomRangesForDepthDataDelivery;
@property(nonatomic, readonly) BOOL zoomFactorsOutsideOfVideoZoomRangesForDepthDeliverySupported;

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFCore/AVCaptureReactions.h>
#endif
