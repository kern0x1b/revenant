#import "RevenantAVCapturePhoto.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

CGImageRef RevenantCreatePhotoImage(CMSampleBufferRef photo, size_t longest)
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
    CMSampleBufferRef _revenantPhoto;
    CMSampleBufferRef _revenantPreview;
    AVCaptureResolvedPhotoSettings *_revenantResolvedSettings;
    AVCaptureBracketedStillImageSettings *_revenantBracketSettings;
    NSInteger _revenantPhotoCount;
    NSDictionary *_revenantEmbeddedThumbnailPhotoFormat;
    AVCaptureDeviceType _revenantSourceDeviceType;
}

- (instancetype)initRevenantWithSampleBuffer:(CMSampleBufferRef)photo previewSampleBuffer:(CMSampleBufferRef)preview
                          resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                           bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings photoCount:(NSInteger)photoCount
              embeddedThumbnailPhotoFormat:(NSDictionary *)thumbnailFormat sourceDeviceType:(AVCaptureDeviceType)sourceDeviceType
{
    if ((self = [super init])) {
        _revenantPhoto = photo ? (CMSampleBufferRef)CFRetain(photo) : NULL;
        _revenantPreview = preview ? (CMSampleBufferRef)CFRetain(preview) : NULL;
        _revenantResolvedSettings = resolvedSettings;
        _revenantBracketSettings = bracketSettings;
        _revenantPhotoCount = photoCount;
        _revenantEmbeddedThumbnailPhotoFormat = thumbnailFormat;
        _revenantSourceDeviceType = sourceDeviceType;
    }
    return self;
}

- (void)dealloc
{
    if (_revenantPhoto)
        CFRelease(_revenantPhoto);
    if (_revenantPreview)
        CFRelease(_revenantPreview);
}

- (BOOL)revenant_isCompressed
{
    CMFormatDescriptionRef format = _revenantPhoto ? CMSampleBufferGetFormatDescription(_revenantPhoto) : NULL;
    return format && CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_JPEG;
}

- (CMTime)timestamp
{
    return _revenantPhoto ? CMSampleBufferGetPresentationTimeStamp(_revenantPhoto) : kCMTimeInvalid;
}

- (BOOL)isRawPhoto
{
    return NO;
}

- (CVPixelBufferRef)pixelBuffer
{
    if (!_revenantPhoto || [self revenant_isCompressed])
        return NULL;
    return CMSampleBufferGetImageBuffer(_revenantPhoto);
}

- (CVPixelBufferRef)previewPixelBuffer
{
    return _revenantPreview ? CMSampleBufferGetImageBuffer(_revenantPreview) : NULL;
}

- (NSDictionary<NSString *, id> *)embeddedThumbnailPhotoFormat
{
    return _revenantEmbeddedThumbnailPhotoFormat;
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
    NSData *data = _revenantPhoto && [self revenant_isCompressed] ? [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:_revenantPhoto] : nil;
    CGImageSourceRef source = data ? CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL) : NULL;
    if (source) {
        metadata = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
        CFRelease(source);
    }
    return metadata ?: @{};
}

- (AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    return _revenantResolvedSettings;
}

- (NSInteger)photoCount
{
    return _revenantPhotoCount;
}

- (AVCaptureDeviceType)sourceDeviceType
{
    return _revenantSourceDeviceType;
}

- (AVCaptureBracketedStillImageSettings *)bracketSettings
{
    return _revenantBracketSettings;
}

- (NSData *)fileDataRepresentation
{
    if (!_revenantPhoto || ![self revenant_isCompressed])
        return nil;
    return [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:_revenantPhoto];
}

- (CGImageRef)CGImageRepresentation
{
    CGImageRef image = _revenantPhoto ? RevenantCreatePhotoImage(_revenantPhoto, SIZE_MAX) : NULL;
    return image ? (CGImageRef)CFAutorelease(image) : NULL;
}

- (CGImageRef)previewCGImageRepresentation
{
    CGImageRef image = _revenantPreview ? RevenantCreatePhotoImage(_revenantPreview, SIZE_MAX) : NULL;
    return image ? (CGImageRef)CFAutorelease(image) : NULL;
}

@end
