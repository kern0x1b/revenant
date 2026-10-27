#import "VNBarcodeDecoder.h"
#import "VNBarcodeDecoderCore.hpp"
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

static CIImage *revenant_barcode_image(id image)
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

static CGPoint revenant_barcode_orient_point(CGPoint point, CGImagePropertyOrientation orientation, size_t width, size_t height)
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

static CIContext *revenant_barcode_context(void)
{
    static CIContext *context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        context = [CIContext contextWithOptions:nil];
    });
    return context;
}

NSArray *RevenantVisionBarcodes(id image, CGImagePropertyOrientation orientation, NSArray *symbologies, NSError **error)
{
    CIImage *ciImage = revenant_barcode_image(image);
    CGRect extent = ciImage.extent;
    if (CGRectIsEmpty(extent) || !isfinite(extent.size.width) || !isfinite(extent.size.height)) {
        if (error)
            *error = [NSError errorWithDomain:@"RevenantVisionBarcode" code:1 userInfo:@{NSLocalizedDescriptionKey: @"the image has no pixels"}];
        return nil;
    }
    size_t width = (size_t)ceil(extent.size.width);
    size_t height = (size_t)ceil(extent.size.height);
    if (width == 0 || height == 0 || width > 8192 || height > 8192 || width > SIZE_MAX / height / 4) {
        if (error)
            *error = [NSError errorWithDomain:@"RevenantVisionBarcode" code:1 userInfo:@{NSLocalizedDescriptionKey: @"the image dimensions are not supported"}];
        return nil;
    }
    CIImage *translated = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(-extent.origin.x, -extent.origin.y)];
    std::vector<uint8_t> rgba(width * height * 4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    [revenant_barcode_context() render:translated toBitmap:rgba.data() rowBytes:width * 4 bounds:CGRectMake(0, 0, width, height) format:kCIFormatRGBA8 colorSpace:colorSpace];
    CGColorSpaceRelease(colorSpace);
    size_t outputWidth = (orientation >= kCGImagePropertyOrientationLeftMirrored && orientation <= kCGImagePropertyOrientationLeft) ? height : width;
    size_t outputHeight = outputWidth == height ? width : height;
    std::vector<uint8_t> gray(outputWidth * outputHeight);
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            size_t offset = (y * width + x) * 4;
            uint8_t luminance = (uint8_t)((306 * rgba[offset] + 601 * rgba[offset + 1] + 117 * rgba[offset + 2] + 512) >> 10);
            CGPoint point = revenant_barcode_orient_point(CGPointMake(x, y), orientation, width, height);
            gray[(size_t)point.y * outputWidth + (size_t)point.x] = luminance;
        }
    }
    std::vector<RevenantBarcodeObservation> decoded = RevenantBarcodeDecode(gray.data(), (int)outputWidth, (int)outputHeight);
    NSMutableArray *observations = [NSMutableArray arrayWithCapacity:decoded.size()];
    for (const RevenantBarcodeObservation& item : decoded) {
        NSString *symbology = item.format == ZXing::BarcodeFormat::QRCode ? @"VNBarcodeSymbologyQR" : @"VNBarcodeSymbologyPDF417";
        if (![symbologies containsObject:symbology])
            continue;
        [observations addObject:@{@"payload": [NSString stringWithUTF8String:item.payload.c_str()],
                                  @"symbology": symbology,
                                  @"bounds": @[@(item.boundingBox.x), @(item.boundingBox.y), @(item.boundingBox.width), @(item.boundingBox.height)],
                                  @"corners": @[@[@(item.topLeft.x), @(item.topLeft.y)], @[@(item.topRight.x), @(item.topRight.y)],
                                                @[@(item.bottomRight.x), @(item.bottomRight.y)], @[@(item.bottomLeft.x), @(item.bottomLeft.y)]]}];
    }
    return observations;
}
