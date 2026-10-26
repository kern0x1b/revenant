#import "VNRectangleImage.h"
#import "VNRectangleDetector.h"
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <stdlib.h>
#import <string.h>

@interface VNRectangleObservation (RevenantRectangleCorners)
- (void)revenant_setCornersTopLeft:(CGPoint)topLeft topRight:(CGPoint)topRight bottomRight:(CGPoint)bottomRight bottomLeft:(CGPoint)bottomLeft;
@end

static CIContext *revenant_rectangle_context(void)
{
    static CIContext *context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ context = [CIContext contextWithOptions:nil]; });
    return context;
}

static CIImage *revenant_rectangle_image(id image)
{
    CFTypeID type = image != nil ? CFGetTypeID((__bridge CFTypeRef)image) : 0;
    if ([image isKindOfClass:[CIImage class]]) return image;
    if ([image isKindOfClass:[NSURL class]]) return [CIImage imageWithContentsOfURL:image];
    if ([image isKindOfClass:[NSData class]]) return [CIImage imageWithData:image];
    if (type == CGImageGetTypeID()) return [CIImage imageWithCGImage:(__bridge CGImageRef)image];
    if (type == CVPixelBufferGetTypeID()) return [CIImage imageWithCVPixelBuffer:(__bridge CVPixelBufferRef)image];
    return nil;
}

NSArray *RevenantVisionRectangles(id image, CGImagePropertyOrientation orientation, id request, NSError **error)
{
    VNDetectRectanglesRequest *rectangleRequest = request;
    CIImage *source = revenant_rectangle_image(image);
    CGRect extent = source.extent;
    if (CGRectIsEmpty(extent) || !isfinite(extent.size.width) || !isfinite(extent.size.height)) {
        if (error) *error = [NSError errorWithDomain:@"com.apple.Vision" code:3 userInfo:@{NSLocalizedDescriptionKey: @"the image has no pixels"}];
        return nil;
    }
    size_t sourceWidth = (size_t)ceil(extent.size.width), sourceHeight = (size_t)ceil(extent.size.height);
    if (!sourceWidth || !sourceHeight || sourceWidth > 8192 || sourceHeight > 8192) {
        if (error) *error = [NSError errorWithDomain:@"com.apple.Vision" code:3 userInfo:@{NSLocalizedDescriptionKey: @"the image dimensions are not supported"}];
        return nil;
    }
    BOOL swapped = orientation >= kCGImagePropertyOrientationLeftMirrored && orientation <= kCGImagePropertyOrientationLeft;
    size_t orientedWidth = swapped ? sourceHeight : sourceWidth, orientedHeight = swapped ? sourceWidth : sourceHeight;
    size_t scale = (orientedWidth > 320 || orientedHeight > 320) ? (size_t)ceil(MAX((double)orientedWidth / 320.0, (double)orientedHeight / 320.0)) : 1;
    size_t inputWidth = (sourceWidth + scale - 1) / scale, inputHeight = (sourceHeight + scale - 1) / scale;
    size_t width = swapped ? inputHeight : inputWidth, height = swapped ? inputWidth : inputHeight;
    CIImage *translated = [source imageByApplyingTransform:CGAffineTransformMakeTranslation(-extent.origin.x, -extent.origin.y)];
    if (scale > 1)
        translated = [translated imageByApplyingTransform:CGAffineTransformMakeScale(1.0 / scale, 1.0 / scale)];
    uint8_t *rgba = malloc(inputWidth * inputHeight * 4);
    uint8_t *gray = malloc(width * height);
    if (!rgba || !gray) {
        free(rgba); free(gray);
        if (error) *error = [NSError errorWithDomain:@"com.apple.Vision" code:9 userInfo:@{NSLocalizedDescriptionKey: @"rectangle detector ran out of memory"}];
        return nil;
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    [revenant_rectangle_context() render:translated toBitmap:rgba rowBytes:inputWidth * 4 bounds:CGRectMake(0, 0, inputWidth, inputHeight) format:kCIFormatRGBA8 colorSpace:colorSpace];
    CGColorSpaceRelease(colorSpace);
    memset(gray, 0, width * height);
    for (size_t y = 0; y < inputHeight; ++y) {
        for (size_t x = 0; x < inputWidth; ++x) {
            size_t offset = (y * inputWidth + x) * 4;
            size_t ox = x, oy = y;
            switch (orientation) {
                case kCGImagePropertyOrientationUpMirrored: ox = inputWidth - 1 - x; break;
                case kCGImagePropertyOrientationDown: ox = inputWidth - 1 - x; oy = inputHeight - 1 - y; break;
                case kCGImagePropertyOrientationDownMirrored: oy = inputHeight - 1 - y; break;
                case kCGImagePropertyOrientationLeftMirrored: ox = y; oy = x; break;
                case kCGImagePropertyOrientationRight: ox = inputHeight - 1 - y; oy = x; break;
                case kCGImagePropertyOrientationRightMirrored: ox = inputHeight - 1 - y; oy = inputWidth - 1 - x; break;
                case kCGImagePropertyOrientationLeft: ox = y; oy = inputWidth - 1 - x; break;
                default: break;
            }
            gray[oy * width + ox] = (uint8_t)((306 * rgba[offset] + 601 * rgba[offset + 1] + 117 * rgba[offset + 2] + 512) >> 10);
        }
    }
    size_t capacity = width * height / 16;
    size_t maximum = rectangleRequest.maximumObservations;
    RevenantVisionRectangle *rectangles = calloc(capacity, sizeof(RevenantVisionRectangle));
    if (!rectangles) {
        free(rgba); free(gray);
        if (error) *error = [NSError errorWithDomain:@"com.apple.Vision" code:9 userInfo:@{NSLocalizedDescriptionKey: @"rectangle detector ran out of memory"}];
        return nil;
    }
    RevenantVisionRectangleOptions options = {rectangleRequest.minimumAspectRatio, rectangleRequest.maximumAspectRatio,
        rectangleRequest.quadratureTolerance, rectangleRequest.minimumSize, rectangleRequest.minimumConfidence, maximum};
    size_t count = RevenantVisionDetectRectangles(gray, width, height, width, options, rectangles, capacity);
    if (count == SIZE_MAX) {
        free(rectangles); free(rgba); free(gray);
        if (error) *error = [NSError errorWithDomain:@"com.apple.Vision" code:9 userInfo:@{NSLocalizedDescriptionKey: @"rectangle detector ran out of memory"}];
        return nil;
    }
    NSMutableArray *observations = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; ++i) {
        RevenantVisionRectangle item = rectangles[i];
        float minX = 1, minY = 1, maxX = 0, maxY = 0;
        for (int j = 0; j < 4; ++j) {
            minX = fminf(minX, item.corners[j].x); minY = fminf(minY, item.corners[j].y);
            maxX = fmaxf(maxX, item.corners[j].x); maxY = fmaxf(maxY, item.corners[j].y);
        }
        VNRectangleObservation *observation = [VNRectangleObservation observationWithRequestRevision:[request revision]
                                                                                          boundingBox:CGRectMake(minX, minY, maxX - minX, maxY - minY)];
        [observation revenant_setCornersTopLeft:CGPointMake(item.corners[0].x, item.corners[0].y)
                                      topRight:CGPointMake(item.corners[1].x, item.corners[1].y)
                                   bottomRight:CGPointMake(item.corners[2].x, item.corners[2].y)
                                    bottomLeft:CGPointMake(item.corners[3].x, item.corners[3].y)];
        [observations addObject:observation];
    }
    free(rectangles); free(rgba); free(gray);
    return observations;
}
