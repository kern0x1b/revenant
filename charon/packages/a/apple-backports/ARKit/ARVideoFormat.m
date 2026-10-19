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
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(_format.formatDescription);
    return CGSizeMake(dimensions.width, dimensions.height);
}

- (NSInteger)framesPerSecond
{
    NSArray *ranges = _format.videoSupportedFrameRateRanges;
    if (ranges.count == 0)
        return 0;
    return (NSInteger)[ranges[0] maxFrameRate];
}

- (BOOL)isVideoHDRSupported
{
    return NO;
}

- (BOOL)isRecommendedForHighResolutionFrameCapturing
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
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
