#import "CharonVision.h"

/* What iOS 15 added to Vision that is data rather than a model: six barcode symbologies, each named by its own string,
 * and the four conversions a region of interest adds to the normalized coordinates. The conversions are arithmetic over
 * doubles, measured on the host Vision of macOS 27.0.1 (facts/Vision/Coordinates.md, tests/backports/host/vision-coordinates15).
 * The barcode symbologies are constants whose values are their names, as the other symbologies are; a request that
 * reads them is not carried. */

VNBarcodeSymbology const VNBarcodeSymbologyCodabar = @"VNBarcodeSymbologyCodabar";
VNBarcodeSymbology const VNBarcodeSymbologyGS1DataBar = @"VNBarcodeSymbologyGS1DataBar";
VNBarcodeSymbology const VNBarcodeSymbologyGS1DataBarExpanded = @"VNBarcodeSymbologyGS1DataBarExpanded";
VNBarcodeSymbology const VNBarcodeSymbologyGS1DataBarLimited = @"VNBarcodeSymbologyGS1DataBarLimited";
VNBarcodeSymbology const VNBarcodeSymbologyMicroPDF417 = @"VNBarcodeSymbologyMicroPDF417";
VNBarcodeSymbology const VNBarcodeSymbologyMicroQR = @"VNBarcodeSymbologyMicroQR";

/* The image point of a point normalized inside a region of interest: the region's origin plus the point's share of its
 * size, scaled to the image. */
CGPoint VNImagePointForNormalizedPointUsingRegionOfInterest(CGPoint normalizedPoint, size_t imageWidth, size_t imageHeight, CGRect regionOfInterest)
{
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGPointMake((regionOfInterest.origin.x + normalizedPoint.x * regionOfInterest.size.width) * width,
                       (regionOfInterest.origin.y + normalizedPoint.y * regionOfInterest.size.height) * height);
}

/* The inverse: an image point as a point normalized inside the region. An image with a zero width or height has no
 * normalized coordinates, and the answer is the zero point. A zero-sized region is not guarded: the division gives the
 * infinities and NaN the release gives. */
CGPoint VNNormalizedPointForImagePointUsingRegionOfInterest(CGPoint imagePoint, size_t imageWidth, size_t imageHeight, CGRect regionOfInterest)
{
    if (imageWidth == 0 || imageHeight == 0) {
        return CGPointZero;
    }
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGPointMake((imagePoint.x - regionOfInterest.origin.x * width) / (regionOfInterest.size.width * width),
                       (imagePoint.y - regionOfInterest.origin.y * height) / (regionOfInterest.size.height * height));
}

/* The image rectangle of a rectangle normalized inside a region of interest: the origin is the region's origin plus the
 * rectangle's share of the region, scaled to the image, and the size is the rectangle's share of the region's size,
 * scaled the same way. The size is computed from the size and not as the distance between two edges: the edge distance
 * differs in the last bit for some values, and it gives +0 where a negative size in a zero-width region gives -0, both
 * measured. */
CGRect VNImageRectForNormalizedRectUsingRegionOfInterest(CGRect normalizedRect, size_t imageWidth, size_t imageHeight, CGRect regionOfInterest)
{
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGRectMake((regionOfInterest.origin.x + normalizedRect.origin.x * regionOfInterest.size.width) * width,
                      (regionOfInterest.origin.y + normalizedRect.origin.y * regionOfInterest.size.height) * height,
                      normalizedRect.size.width * regionOfInterest.size.width * width,
                      normalizedRect.size.height * regionOfInterest.size.height * height);
}

/* The inverse of the one above: an image rectangle as a rectangle normalized inside the region. An image with a zero width
 * or height gives the zero rectangle. */
CGRect VNNormalizedRectForImageRectUsingRegionOfInterest(CGRect imageRect, size_t imageWidth, size_t imageHeight, CGRect regionOfInterest)
{
    if (imageWidth == 0 || imageHeight == 0) {
        return CGRectZero;
    }
    double width = (double)imageWidth, height = (double)imageHeight;
    /* A negative size is no size: it is read as zero before the edges are taken, so the size comes out zero. In a
     * zero-sized region both edges are infinite and their difference is NaN, which the release answers too. */
    double sw = imageRect.size.width < 0 ? 0 : imageRect.size.width;
    double sh = imageRect.size.height < 0 ? 0 : imageRect.size.height;
    double minX = imageRect.origin.x - regionOfInterest.origin.x * width;
    double maxX = imageRect.origin.x + sw - regionOfInterest.origin.x * width;
    double minY = imageRect.origin.y - regionOfInterest.origin.y * height;
    double maxY = imageRect.origin.y + sh - regionOfInterest.origin.y * height;
    double rw = regionOfInterest.size.width * width, rh = regionOfInterest.size.height * height;
    return CGRectMake(minX / rw, minY / rh, maxX / rw - minX / rw, maxY / rh - minY / rh);
}

/* The contrast pivot of the contour request, which the release has from 15.0: its value is held by the 14.0 class, where the
 * request's other properties are. */
@implementation VNDetectContoursRequest (CharonVision15ContrastPivot)

- (NSNumber *)contrastPivot
{
    return [self charon_contrastPivotValue];
}

- (void)setContrastPivot:(NSNumber *)contrastPivot
{
    [self charon_setContrastPivotValue:contrastPivot];
}

@end
