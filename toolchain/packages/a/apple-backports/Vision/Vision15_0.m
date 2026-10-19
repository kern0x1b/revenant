#import "RevenantVision.h"

VNBarcodeSymbology const VNBarcodeSymbologyCodabar = @"VNBarcodeSymbologyCodabar";
VNBarcodeSymbology const VNBarcodeSymbologyGS1DataBar = @"VNBarcodeSymbologyGS1DataBar";
VNBarcodeSymbology const VNBarcodeSymbologyGS1DataBarExpanded = @"VNBarcodeSymbologyGS1DataBarExpanded";
VNBarcodeSymbology const VNBarcodeSymbologyGS1DataBarLimited = @"VNBarcodeSymbologyGS1DataBarLimited";
VNBarcodeSymbology const VNBarcodeSymbologyMicroPDF417 = @"VNBarcodeSymbologyMicroPDF417";
VNBarcodeSymbology const VNBarcodeSymbologyMicroQR = @"VNBarcodeSymbologyMicroQR";

CGPoint VNImagePointForNormalizedPointUsingRegionOfInterest(CGPoint normalizedPoint, size_t imageWidth, size_t imageHeight, CGRect regionOfInterest)
{
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGPointMake((regionOfInterest.origin.x + normalizedPoint.x * regionOfInterest.size.width) * width,
                       (regionOfInterest.origin.y + normalizedPoint.y * regionOfInterest.size.height) * height);
}

CGPoint VNNormalizedPointForImagePointUsingRegionOfInterest(CGPoint imagePoint, size_t imageWidth, size_t imageHeight, CGRect regionOfInterest)
{
    if (imageWidth == 0 || imageHeight == 0) {
        return CGPointZero;
    }
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGPointMake((imagePoint.x - regionOfInterest.origin.x * width) / (regionOfInterest.size.width * width),
                       (imagePoint.y - regionOfInterest.origin.y * height) / (regionOfInterest.size.height * height));
}

CGRect VNImageRectForNormalizedRectUsingRegionOfInterest(CGRect normalizedRect, size_t imageWidth, size_t imageHeight, CGRect regionOfInterest)
{
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGRectMake((regionOfInterest.origin.x + normalizedRect.origin.x * regionOfInterest.size.width) * width,
                      (regionOfInterest.origin.y + normalizedRect.origin.y * regionOfInterest.size.height) * height,
                      normalizedRect.size.width * regionOfInterest.size.width * width,
                      normalizedRect.size.height * regionOfInterest.size.height * height);
}

CGRect VNNormalizedRectForImageRectUsingRegionOfInterest(CGRect imageRect, size_t imageWidth, size_t imageHeight, CGRect regionOfInterest)
{
    if (imageWidth == 0 || imageHeight == 0) {
        return CGRectZero;
    }
    double width = (double)imageWidth, height = (double)imageHeight;
    double sw = imageRect.size.width < 0 ? 0 : imageRect.size.width;
    double sh = imageRect.size.height < 0 ? 0 : imageRect.size.height;
    double minX = imageRect.origin.x - regionOfInterest.origin.x * width;
    double maxX = imageRect.origin.x + sw - regionOfInterest.origin.x * width;
    double minY = imageRect.origin.y - regionOfInterest.origin.y * height;
    double maxY = imageRect.origin.y + sh - regionOfInterest.origin.y * height;
    double rw = regionOfInterest.size.width * width, rh = regionOfInterest.size.height * height;
    return CGRectMake(minX / rw, minY / rh, maxX / rw - minX / rw, maxY / rh - minY / rh);
}

@implementation VNDetectContoursRequest (RevenantVision15ContrastPivot)

- (NSNumber *)contrastPivot
{
    return [self revenant_contrastPivotValue];
}

- (void)setContrastPivot:(NSNumber *)contrastPivot
{
    [self revenant_setContrastPivotValue:contrastPivot];
}

@end
