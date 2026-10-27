#import "VNGrayscale.h"
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

static CIImage *revenant_gray_image(id image)
{
    CFTypeID type = image != nil ? CFGetTypeID((__bridge CFTypeRef)image) : 0;
    if ([image isKindOfClass:[CIImage class]])
        return image;
    if ([image isKindOfClass:[NSURL class]])
        return [CIImage imageWithContentsOfURL:image];
    if ([image isKindOfClass:[NSData class]])
        return [CIImage imageWithData:image];
    if (type == CGImageGetTypeID())
        return [CIImage imageWithCGImage:(__bridge CGImageRef)image];
    if (type == CVPixelBufferGetTypeID())
        return [CIImage imageWithCVPixelBuffer:(__bridge CVPixelBufferRef)image];
    return nil;
}

static CGPoint revenant_gray_orient_point(CGPoint point, CGImagePropertyOrientation orientation, size_t width, size_t height)
{
    switch (orientation) {
        case kCGImagePropertyOrientationUpMirrored:
            return CGPointMake(width - 1 - point.x, point.y);
        case kCGImagePropertyOrientationDown:
            return CGPointMake(width - 1 - point.x, height - 1 - point.y);
        case kCGImagePropertyOrientationDownMirrored:
            return CGPointMake(point.x, height - 1 - point.y);
        case kCGImagePropertyOrientationLeftMirrored:
            return CGPointMake(point.y, point.x);
        case kCGImagePropertyOrientationRight:
            return CGPointMake(height - 1 - point.y, point.x);
        case kCGImagePropertyOrientationRightMirrored:
            return CGPointMake(height - 1 - point.y, width - 1 - point.x);
        case kCGImagePropertyOrientationLeft:
            return CGPointMake(point.y, width - 1 - point.x);
        default:
            return point;
    }
}

static CIContext *revenant_gray_context(void)
{
    static CIContext *context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        context = [CIContext contextWithOptions:nil];
    });
    return context;
}

static NSError *revenant_gray_error(NSString *description)
{
    return [NSError errorWithDomain:@"RevenantVisionImage" code:1 userInfo:@{NSLocalizedDescriptionKey: description}];
}

NSData *RevenantVisionGrayscale(id image, CGImagePropertyOrientation orientation, size_t *outputWidth, size_t *outputHeight, NSError **error)
{
    CIImage *ciImage = revenant_gray_image(image);
    CGRect extent = ciImage.extent;
    if (CGRectIsEmpty(extent) || !isfinite(extent.size.width) || !isfinite(extent.size.height)) {
        if (error)
            *error = revenant_gray_error(@"the image has no pixels");
        return nil;
    }
    size_t width = (size_t)ceil(extent.size.width);
    size_t height = (size_t)ceil(extent.size.height);
    if (width == 0 || height == 0 || width > 8192 || height > 8192 || width > SIZE_MAX / height / 4) {
        if (error)
            *error = revenant_gray_error(@"the image dimensions are not supported");
        return nil;
    }
    CIImage *translated = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(-extent.origin.x, -extent.origin.y)];
    NSMutableData *rgba = [NSMutableData dataWithLength:width * height * 4];
    uint8_t *pixels = rgba.mutableBytes;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    [revenant_gray_context() render:translated toBitmap:pixels rowBytes:width * 4 bounds:CGRectMake(0, 0, width, height) format:kCIFormatRGBA8 colorSpace:colorSpace];
    CGColorSpaceRelease(colorSpace);
    size_t wide = (orientation >= kCGImagePropertyOrientationLeftMirrored && orientation <= kCGImagePropertyOrientationLeft) ? height : width;
    size_t high = wide == height ? width : height;
    NSMutableData *gray = [NSMutableData dataWithLength:wide * high];
    uint8_t *luminance = gray.mutableBytes;
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            size_t offset = (y * width + x) * 4;
            uint8_t value = (uint8_t)((306 * pixels[offset] + 601 * pixels[offset + 1] + 117 * pixels[offset + 2] + 512) >> 10);
            CGPoint point = revenant_gray_orient_point(CGPointMake(x, y), orientation, width, height);
            luminance[(size_t)point.y * wide + (size_t)point.x] = value;
        }
    }
    if (outputWidth)
        *outputWidth = wide;
    if (outputHeight)
        *outputHeight = high;
    return gray;
}
