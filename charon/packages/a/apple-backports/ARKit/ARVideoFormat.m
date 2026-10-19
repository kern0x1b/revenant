// ARVideoFormat.m - one camera configuration an application may ask the session for.
//
// ARKit hands this class out instead of AVCaptureDeviceFormat so that the shape of a format can be
// compared across devices: what a format is on this device is read off the camera the session would
// actually capture from, and a format the camera does not have is never offered.

#import <ARKit/ARKit.h>
#import <CoreMedia/CoreMedia.h>

#import "CharonARKitPrivate.h"
#import "CharonARTracker.h"

@interface ARVideoFormat () {
@public
    AVCaptureDeviceFormat *_format;
    AVCaptureDevicePosition _position;
}
@end

@implementation ARVideoFormat


    @synthesize imageResolution = _imageResolution;
    @synthesize framesPerSecond = _framesPerSecond;
- (instancetype)initWithCaptureFormat:(AVCaptureDeviceFormat *)format
{
    self = [super init];
    if (!self)
        return nil;
    _format = format;
    _position = [self deviceOwningFormat:format].position;
    return self;
}

/// The camera a format belongs to. A 6.1.3 `AVCaptureDeviceFormat` carries no back-reference to
/// one, and the same object is handed out for more than one camera, so the camera is the one whose
/// `formats` list actually contains it.
- (AVCaptureDevice *)deviceOwningFormat:(AVCaptureDeviceFormat *)format
{
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([device hasMediaType:AVMediaTypeVideo] && [device.formats containsObject:format])
            return device;
    }
    return nil;
}

- (AVCaptureDevicePosition)captureDevicePosition
{
    return _position;
}

- (CGSize)imageResolution
{
    // The dimensions the format describes are the width and the height of the buffer the camera
    // delivers, which the format description carries.
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(_format.formatDescription);
    return CGSizeMake(dimensions.width, dimensions.height);
}

- (NSInteger)framesPerSecond
{
    NSArray *ranges = _format.videoSupportedFrameRateRanges;
    if (ranges.count == 0)
        return 0;
    // The fastest rate the range allows, which is the one the capture output would run at.
    return (NSInteger)[ranges[0] maxFrameRate];
}

- (BOOL)isVideoHDRSupported
{
    // HDR is a property of the format's pixel format on the releases that have one at all, and this
    // framework is built for releases whose cameras are not described that way, so the answer is the
    // one the camera gives for a format it cannot describe that way: no.
    return NO;
}

- (BOOL)isRecommendedForHighResolutionFrameCapturing
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A format is the camera's own, and handing out the same object for a copy would let a caller
    // change what the session captures with; the copy is a new object over the same format.
    ARVideoFormat *copy = [[ARVideoFormat allocWithZone:zone] initWithCaptureFormat:_format];
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; %.0fx%.0f @ %ld>",
            NSStringFromClass([self class]), self, self.imageResolution.width, self.imageResolution.height,
            (long)self.framesPerSecond];
}

@end
