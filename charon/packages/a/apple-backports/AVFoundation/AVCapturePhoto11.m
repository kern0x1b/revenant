#import "CharonAVCapturePhoto.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

// The captured still as an image no longer on its longest side than `longest`: a JPEG through ImageIO's
// thumbnail, which decodes at the reduced size; an uncompressed buffer through CoreImage.
CGImageRef CharonCreatePhotoImage(CMSampleBufferRef photo, size_t longest)
{
    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(photo);
    if (format && CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_JPEG) {
        NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:photo];
        CGImageSourceRef source = data ? CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL) : NULL;
        if (!source)
            return NULL;
        // No reduction asked (SIZE_MAX, the full image): the whole image decodes; a thumbnail at an unbounded size is not one.
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
    // CoreImage converts the buffer. On 6.1.3 it makes an image from an IOSurface-backed buffer and gives a nil image from a plain
    // one (measured on the release: facts/AVFoundation/AVCapturePhoto11.md, "CoreImage on 6.1.3").
    CIImage *image = [CIImage imageWithCVPixelBuffer:buffer];
    return [[CIContext contextWithOptions:nil] createCGImage:image fromRect:image.extent];
}


// AVCapturePhoto, iOS 11.0: the photo a capture hands its delegate through -captureOutput:didFinishProcessingPhoto:error:
// (facts/AVFoundation/AVCapturePhoto11.md). 6.1.3 has no such class, so the port defines it; the still it holds is the
// sample buffer AVCapturePhotoOutput took from the still image output, retained here, and every member answers from that
// sample or from the settings the capture resolved. The members the port cannot make answer nil or the header's default:
// there is no depth, no portrait matte, no calibration and no RAW on the 4S's still output (facts, "Not carried").
//
// The object is made for every photo, the error ones too: the header says the photo parameter is non nil even when an
// error is returned, so an error photo holds no sample and answers nothing from one.
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

// Whether the still is a file format container (JPEG) rather than an uncompressed buffer such as BGRA.
- (BOOL)charon_isCompressed
{
    CMFormatDescriptionRef format = _charonPhoto ? CMSampleBufferGetFormatDescription(_charonPhoto) : NULL;
    return format && CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_JPEG;
}

// The presentation time of the still: the time the camera took it (the sample's own timestamp).
- (CMTime)timestamp
{
    return _charonPhoto ? CMSampleBufferGetPresentationTimeStamp(_charonPhoto) : kCMTimeInvalid;
}

// 6.1.3's still output makes no RAW photo, so no photo the port delivers is one.
- (BOOL)isRawPhoto
{
    return NO;
}

// The uncompressed buffer of the still; nil for a JPEG, which has no pixel buffer of its own (the header: NULL for
// processed compressed photos).
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

// The thumbnail the settings asked for, as the settings gave it; the photo's own thumbnail is embedded in the still.
- (NSDictionary<NSString *, id> *)embeddedThumbnailPhotoFormat
{
    return _charonEmbeddedThumbnailPhotoFormat;
}

// No depth: the port's output does not deliver depth data (facts, "Not carried").
- (AVDepthData *)depthData
{
    return nil;
}

// No portrait effect on 6.1.3 (facts, "Not carried").
- (AVPortraitEffectsMatte *)portraitEffectsMatte
{
    return nil;
}

// No semantic segmentation matte: the port's photo output makes none, for any type (facts, "Not carried").
- (AVSemanticSegmentationMatte *)semanticSegmentationMatteForType:(AVSemanticSegmentationMatteType)semanticSegmentationMatteType
{
    return nil;
}

// No calibration on the 4S's still output: the calibration rows of the port are absent (facts/AVFoundation/DepthData11.md).
- (AVCameraCalibrationData *)cameraCalibrationData
{
    return nil;
}

// The metadata of the photo: the properties of its JPEG container, read by ImageIO. An uncompressed photo has none.
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

// The device type of the camera that took the photo: the capture's own camera, as AVCaptureDevice's deviceType names it
// (AVCaptureDevice+DeviceType.m). The 4S's back camera is a wide angle camera. A photo made without a camera names none.
- (AVCaptureDeviceType)sourceDeviceType
{
    return _charonSourceDeviceType;
}

// iOS 11.0 bracketed capture: the bracket setting this photo was taken for, nil for a photo of a single capture.
- (AVCaptureBracketedStillImageSettings *)bracketSettings
{
    return _charonBracketSettings;
}

// The file the photo is: a JPEG's own bytes, which carry the metadata and the thumbnail the still was taken with; nil for an
// uncompressed photo, which has no file container on this release (the header: nil when there is no file representation).
- (NSData *)fileDataRepresentation
{
    if (!_charonPhoto || ![self charon_isCompressed])
        return nil;
    return [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:_charonPhoto];
}

// The still as a CGImage, decoded from its container or converted from its buffer, at full size; a new image on each call.
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
