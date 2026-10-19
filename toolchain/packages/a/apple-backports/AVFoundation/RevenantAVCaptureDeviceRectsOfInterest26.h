#if !defined(__IPHONE_26_0)
#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVCaptureDevice.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVCaptureDevice (CharonCaptureDeviceRectsOfInterest26)

@property(nonatomic, readonly, getter=isFocusRectOfInterestSupported) BOOL focusRectOfInterestSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CGSize minFocusRectOfInterestSize API_AVAILABLE(ios(26.0));
@property(nonatomic) CGRect focusRectOfInterest API_AVAILABLE(ios(26.0));
- (CGRect)defaultRectForFocusPointOfInterest:(CGPoint)pointOfInterest API_AVAILABLE(ios(26.0));

@property(nonatomic, readonly, getter=isExposureRectOfInterestSupported) BOOL exposureRectOfInterestSupported API_AVAILABLE(ios(26.0));
@property(nonatomic, readonly) CGSize minExposureRectOfInterestSize API_AVAILABLE(ios(26.0));
@property(nonatomic) CGRect exposureRectOfInterest API_AVAILABLE(ios(26.0));
- (CGRect)defaultRectForExposurePointOfInterest:(CGPoint)pointOfInterest API_AVAILABLE(ios(26.0));

@end

NS_ASSUME_NONNULL_END

#else
#import <AVFoundation/AVCaptureDevice.h>
#endif
