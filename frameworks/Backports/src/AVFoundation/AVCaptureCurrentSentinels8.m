#include "../revenant_impl.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

const float BACKPORT_IMPL(AVCaptureISOCurrent) = 3.40282347e+38f;
const float BACKPORT_IMPL(AVCaptureExposureTargetBiasCurrent) = 3.40282347e+38f;
const float BACKPORT_IMPL(AVCaptureLensPositionCurrent) = 3.40282347e+38f;
const AVCaptureWhiteBalanceGains BACKPORT_IMPL(AVCaptureWhiteBalanceGainsCurrent) = {0.0f, 0.0f};
const CMTime BACKPORT_IMPL(AVCaptureExposureDurationCurrent) = {0, 0, 0, 0};
