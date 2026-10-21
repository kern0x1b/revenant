#if !__has_include(<AVFCore/AVCaptureReactions.h>)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureDevice.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *AVCaptureReactionType NS_TYPED_ENUM;

@class AVCaptureReactionEffectState;

@class AVZoomRange;

@interface AVCaptureDevice (RevenantCaptureDeviceReactions17)

@property(nonatomic, readonly) NSSet<AVCaptureReactionType> *availableReactionTypes;
@property(nonatomic, readonly) BOOL canPerformReactionEffects;
@property(nonatomic, readonly) NSArray<AVCaptureReactionEffectState *> *reactionEffectsInProgress;
@property(class, readonly) BOOL reactionEffectsEnabled;
@property(class, readonly) BOOL reactionEffectGesturesEnabled;
@property(class, readonly, nullable) AVCaptureDevice *systemPreferredCamera;
@property(class, readwrite, nullable) AVCaptureDevice *userPreferredCamera;
- (void)performEffectForReaction:(AVCaptureReactionType)reactionType NS_SWIFT_NAME(performEffect(for:));

@end

@interface AVCaptureDeviceFormat (RevenantCaptureDeviceFormatReactions17)

@property(nonatomic, readonly) BOOL reactionEffectsSupported;
@property(nonatomic, readonly, nullable) AVFrameRateRange *videoFrameRateRangeForReactionEffectsInProgress;

@end

@interface AVCaptureDeviceFormat (RevenantCaptureDeviceFormatDepthZoom17)

@property(nonatomic, readonly) NSArray<AVZoomRange *> *supportedVideoZoomRangesForDepthDataDelivery;
@property(nonatomic, readonly) BOOL zoomFactorsOutsideOfVideoZoomRangesForDepthDeliverySupported;

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFCore/AVCaptureReactions.h>
#endif
