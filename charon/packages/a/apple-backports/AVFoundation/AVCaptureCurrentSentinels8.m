#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

// The five "…Current" sentinels, iOS 8.
//
// **The corpus calls these `kind: constant` and they are not strings.** Four different types are
// declared for them, and the first version of this slice's scan read all five as `NSString *const`,
// took the address dlsym answered with, sent -UTF8String to it, and SEGFAULTED - which is how they
// were found to be sentinels of value types rather than names. So they are declared here with the
// types the SDK declares and their values are read from the host with those types, not with a string
// cast.
//
// Each is the documented "leave it as it is" answer for the property it names: the ISO, the exposure
// bias, the lens position and the white-balance gains ask the device not to be told, and the exposure
// duration is the invalid time. The values are read out of the host's own AVFoundation and printed
// by the differential in tests/backports/host/avf-notifications:
//
//     AVCaptureExposureDurationCurrent     CMTime { value 0, timescale 0, flags 0 }
//     AVCaptureISOCurrent                 3.40282347e+38   (FLT_MAX)
//     AVCaptureExposureTargetBiasCurrent  3.40282347e+38   (FLT_MAX)
//     AVCaptureLensPositionCurrent        3.40282347e+38   (FLT_MAX)
//     AVCaptureWhiteBalanceGainsCurrent   { redGain 0, blueGain 0 }
//
// The three floats are FLT_MAX, which is what makes them impossible to confuse with a measured
// value: a caller that passed a real ISO by accident could not pass this one. The gains are zero,
// which is a real gain pair and so is NOT a safe sentinel, and the header's own answer for it is what
// is written here rather than something safer-looking.
//
// The 8.0 rung is the first held rung that exports these FIVE names - measured over every held
// cache with _NSFileSize planted as a control, and with a nonsense symbol in none of them - so this is
// one object and no band finds a mix. The five are the two CMTime/float sentinels above plus the
// three FLT_MAX floats; the headline count is five because the file defines five.

const float AVCaptureISOCurrent = 3.40282347e+38f;
const float AVCaptureExposureTargetBiasCurrent = 3.40282347e+38f;
const float AVCaptureLensPositionCurrent = 3.40282347e+38f;
const AVCaptureWhiteBalanceGains AVCaptureWhiteBalanceGainsCurrent = {0.0f, 0.0f};
const CMTime AVCaptureExposureDurationCurrent = {0, 0, 0, 0};
