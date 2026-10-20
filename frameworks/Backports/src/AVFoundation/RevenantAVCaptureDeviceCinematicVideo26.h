#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>

NS_ASSUME_NONNULL_BEGIN


typedef NSString *AVCaptureSceneMonitoringStatus NS_TYPED_ENUM API_AVAILABLE(ios(26.0));

@interface AVCaptureDevice (RevenantCaptureDeviceCinematicVideo26)

@property(nonatomic, readonly) NSSet<AVCaptureSceneMonitoringStatus> *cinematicVideoCaptureSceneMonitoringStatuses API_AVAILABLE(ios(26.0));

- (void)setCinematicVideoTrackingFocusWithDetectedObjectID:(NSInteger)detectedObjectID focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0));
- (void)setCinematicVideoTrackingFocusAtPoint:(CGPoint)point focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0));
- (void)setCinematicVideoFixedFocusAtPoint:(CGPoint)point focusMode:(AVCaptureCinematicVideoFocusMode)focusMode API_AVAILABLE(ios(26.0));

@end

@interface AVCaptureDeviceFormat (RevenantCaptureDeviceFormatCinematicVideo26)

@property(nonatomic, readonly, getter=isCinematicVideoCaptureSupported) BOOL cinematicVideoCaptureSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CGFloat videoMinZoomFactorForCinematicVideo API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CGFloat videoMaxZoomFactorForCinematicVideo API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly, nullable) AVFrameRateRange *videoFrameRateRangeForCinematicVideo API_AVAILABLE(ios(26.0));

@end

@interface AVCaptureDeviceInput (RevenantCaptureDeviceInputCinematicVideo26)

@property(nonatomic, readonly, getter=isCinematicVideoCaptureSupported) BOOL cinematicVideoCaptureSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, getter=isCinematicVideoCaptureEnabled) BOOL cinematicVideoCaptureEnabled API_AVAILABLE(ios(26.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVCaptureInput.h>
#endif
