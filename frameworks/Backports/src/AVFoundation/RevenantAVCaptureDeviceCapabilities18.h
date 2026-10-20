#if !defined(__IPHONE_18_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AVCaptureMultichannelAudioMode) {
    AVCaptureMultichannelAudioModeNone                 = 0,
    AVCaptureMultichannelAudioModeStereo               = 1,
    AVCaptureMultichannelAudioModeFirstOrderAmbisonics = 2,
} API_AVAILABLE(ios(18.0)) API_UNAVAILABLE(watchos);

typedef NSString *AVSpatialCaptureDiscomfortReason NS_TYPED_ENUM API_AVAILABLE(ios(18.0));

@class AVExposureBiasRange;

@class AVZoomRange;

@interface AVCaptureDevice (RevenantCaptureDeviceCapabilities18)

@property(nonatomic, getter=isAutoVideoFrameRateEnabled) BOOL autoVideoFrameRateEnabled API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, getter=isBackgroundReplacementActive) BOOL backgroundReplacementActive API_AVAILABLE(ios(18.0));
@property(class, readonly, getter=isBackgroundReplacementEnabled) BOOL backgroundReplacementEnabled API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly) CGFloat displayVideoZoomFactorMultiplier API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly) NSSet<AVSpatialCaptureDiscomfortReason> *spatialCaptureDiscomfortReasons API_AVAILABLE(ios(18.0));

@end

@interface AVCaptureDeviceFormat (RevenantCaptureDeviceFormatCapabilities18)

@property(nonatomic, readonly, getter=isAutoVideoFrameRateSupported) BOOL autoVideoFrameRateSupported API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, getter=isBackgroundReplacementSupported) BOOL backgroundReplacementSupported API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, getter=isSpatialVideoCaptureSupported) BOOL spatialVideoCaptureSupported API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, nullable) AVExposureBiasRange *systemRecommendedExposureBiasRange API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, nullable) AVZoomRange *systemRecommendedVideoZoomRange API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, nullable) AVFrameRateRange *videoFrameRateRangeForBackgroundReplacement API_AVAILABLE(ios(18.0));

@end

@interface AVCaptureDeviceInput (RevenantCaptureDeviceInputCapabilities18)

- (BOOL)isMultichannelAudioModeSupported:(AVCaptureMultichannelAudioMode)multichannelAudioMode API_AVAILABLE(ios(18.0));
@property(nonatomic) AVCaptureMultichannelAudioMode multichannelAudioMode API_AVAILABLE(ios(18.0));
@property(nonatomic, readonly, getter=isWindNoiseRemovalSupported) BOOL windNoiseRemovalSupported API_AVAILABLE(ios(18.0));
@property(nonatomic, getter=isWindNoiseRemovalEnabled) BOOL windNoiseRemovalEnabled API_AVAILABLE(ios(18.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>
#endif
