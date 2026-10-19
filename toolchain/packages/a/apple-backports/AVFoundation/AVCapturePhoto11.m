#import "CharonAVCapturePhoto.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

CGImageRef CharonCreatePhotoImage(CMSampleBufferRef photo, size_t longest)
{
    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(photo);
    if (format && CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_JPEG) {
        NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:photo];
        CGImageSourceRef source = data ? CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL) : NULL;
        if (!source)
            return NULL;
        if (longest == SIZE_MAX) {
            CGImageRef whole = CGImageSourceCreateImageAtIndex(source, 0, NULL);
            CFRelease(source);
            return whole;
        }
        NSDictionary *options = @{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                                  (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(longest)};
        CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
        CFRelease(source);
        return image;
    }
    CVImageBufferRef buffer = CMSampleBufferGetImageBuffer(photo);
    if (!buffer)
        return NULL;
    CIImage *image = [CIImage imageWithCVPixelBuffer:buffer];
    return [[CIContext contextWithOptions:nil] createCGImage:image fromRect:image.extent];
}


@implementation AVCapturePhoto
{
    CMSampleBufferRef _charonPhoto;
    CMSampleBufferRef _charonPreview;
    AVCaptureResolvedPhotoSettings *_charonResolvedSettings;
    AVCaptureBracketedStillImageSettings *_charonBracketSettings;
    NSInteger _charonPhotoCount;
    NSDictionary *_charonEmbeddedThumbnailPhotoFormat;
    AVCaptureDeviceType _charonSourceDeviceType;
}

- (instancetype)initCharonWithSampleBuffer:(CMSampleBufferRef)photo previewSampleBuffer:(CMSampleBufferRef)preview
                          resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                           bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings photoCount:(NSInteger)photoCount
              embeddedThumbnailPhotoFormat:(NSDictionary *)thumbnailFormat sourceDeviceType:(AVCaptureDeviceType)sourceDeviceType
{
    if ((self = [super init])) {
        _charonPhoto = photo ? (CMSampleBufferRef)CFRetain(photo) : NULL;
        _charonPreview = preview ? (CMSampleBufferRef)CFRetain(preview) : NULL;
        _charonResolvedSettings = resolvedSettings;
        _charonBracketSettings = bracketSettings;
        _charonPhotoCount = photoCount;
        _charonEmbeddedThumbnailPhotoFormat = thumbnailFormat;
        _charonSourceDeviceType = sourceDeviceType;
    }
    return self;
}

- (void)dealloc
{
    if (_charonPhoto)
        CFRelease(_charonPhoto);
    if (_charonPreview)
        CFRelease(_charonPreview);
}

- (BOOL)charon_isCompressed
{
    CMFormatDescriptionRef format = _charonPhoto ? CMSampleBufferGetFormatDescription(_charonPhoto) : NULL;
    return format && CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_JPEG;
}

- (CMTime)timestamp
{
    return _charonPhoto ? CMSampleBufferGetPresentationTimeStamp(_charonPhoto) : kCMTimeInvalid;
}

- (BOOL)isRawPhoto
{
    return NO;
}

- (CVPixelBufferRef)pixelBuffer
{
    if (!_charonPhoto || [self charon_isCompressed])
        return NULL;
    return CMSampleBufferGetImageBuffer(_charonPhoto);
}

- (CVPixelBufferRef)previewPixelBuffer
{
    return _charonPreview ? CMSampleBufferGetImageBuffer(_charonPreview) : NULL;
}

- (NSDictionary<NSString *, id> *)embeddedThumbnailPhotoFormat
{
    return _charonEmbeddedThumbnailPhotoFormat;
}

- (AVDepthData *)depthData
{
    return nil;
}

- (AVPortraitEffectsMatte *)portraitEffectsMatte
{
    return nil;
}

- (AVSemanticSegmentationMatte *)semanticSegmentationMatteForType:(AVSemanticSegmentationMatteType)semanticSegmentationMatteType
{
    return nil;
}

- (AVCameraCalibrationData *)cameraCalibrationData
{
    return nil;
}

- (NSDictionary<NSString *, id> *)metadata
{
    NSDictionary *metadata = nil;
    NSData *data = _charonPhoto && [self charon_isCompressed] ? [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:_charonPhoto] : nil;
    CGImageSourceRef source = data ? CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL) : NULL;
    if (source) {
        metadata = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
        CFRelease(source);
    }
    return metadata ?: @{};
}

- (AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    return _charonResolvedSettings;
}

- (NSInteger)photoCount
{
    return _charonPhotoCount;
}

- (AVCaptureDeviceType)sourceDeviceType
{
    return _charonSourceDeviceType;
}

- (AVCaptureBracketedStillImageSettings *)bracketSettings
{
    return _charonBracketSettings;
}

- (NSData *)fileDataRepresentation
{
    if (!_charonPhoto || ![self charon_isCompressed])
        return nil;
    return [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:_charonPhoto];
}

- (CGImageRef)CGImageRepresentation
{
    CGImageRef image = _charonPhoto ? CharonCreatePhotoImage(_charonPhoto, SIZE_MAX) : NULL;
    return image ? (CGImageRef)CFAutorelease(image) : NULL;
}

- (CGImageRef)previewCGImageRepresentation
{
    CGImageRef image = _charonPreview ? CharonCreatePhotoImage(_charonPreview, SIZE_MAX) : NULL;
    return image ? (CGImageRef)CFAutorelease(image) : NULL;
}

@end
