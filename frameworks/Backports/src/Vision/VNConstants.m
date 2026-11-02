#include "../revenant_impl.h"
#import <Vision/Vision.h>

NSString *const BACKPORT_IMPL(VNErrorDomain) = @"com.apple.Vision";

VNImageOption const BACKPORT_IMPL(VNImageOptionProperties) = @"VNImageOptionProperties";
VNImageOption const BACKPORT_IMPL(VNImageOptionCameraIntrinsics) = @"VNImageOptionCameraIntrinsics";
VNImageOption const BACKPORT_IMPL(VNImageOptionCIContext) = @"VNImageOptionCIContext";

VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyAztec) = @"VNBarcodeSymbologyAztec";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyCode39) = @"VNBarcodeSymbologyCode39";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyCode39Checksum) = @"VNBarcodeSymbologyCode39Checksum";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyCode39FullASCII) = @"VNBarcodeSymbologyCode39FullASCII";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyCode39FullASCIIChecksum) = @"VNBarcodeSymbologyCode39FullASCIIChecksum";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyCode93) = @"VNBarcodeSymbologyCode93";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyCode93i) = @"VNBarcodeSymbologyCode93i";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyCode128) = @"VNBarcodeSymbologyCode128";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyDataMatrix) = @"VNBarcodeSymbologyDataMatrix";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyEAN8) = @"VNBarcodeSymbologyEAN8";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyEAN13) = @"VNBarcodeSymbologyEAN13";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyI2of5) = @"VNBarcodeSymbologyI2of5";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyI2of5Checksum) = @"VNBarcodeSymbologyI2of5Checksum";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyITF14) = @"VNBarcodeSymbologyITF14";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyPDF417) = @"VNBarcodeSymbologyPDF417";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyQR) = @"VNBarcodeSymbologyQR";
VNBarcodeSymbology const BACKPORT_IMPL(VNBarcodeSymbologyUPCE) = @"VNBarcodeSymbologyUPCE";

const CGRect BACKPORT_IMPL(VNNormalizedIdentityRect) = {{0, 0}, {1, 1}};
double BACKPORT_IMPL(VNVisionVersionNumber) = 2.0;

bool BACKPORT_IMPL(VNNormalizedRectIsIdentityRect)(CGRect normalizedRect)
{
    return CGRectEqualToRect(normalizedRect, CGRectMake(0, 0, 1, 1));
}

CGPoint BACKPORT_IMPL(VNImagePointForNormalizedPoint)(CGPoint normalizedPoint, size_t imageWidth, size_t imageHeight)
{
    return CGPointMake(normalizedPoint.x * (double)imageWidth, normalizedPoint.y * (double)imageHeight);
}

CGRect BACKPORT_IMPL(VNImageRectForNormalizedRect)(CGRect normalizedRect, size_t imageWidth, size_t imageHeight)
{
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGRectMake(normalizedRect.origin.x * width, normalizedRect.origin.y * height, normalizedRect.size.width * width, normalizedRect.size.height * height);
}

CGRect BACKPORT_IMPL(VNNormalizedRectForImageRect)(CGRect imageRect, size_t imageWidth, size_t imageHeight)
{
    double x = 0, width = 0, y = 0, height = 0;
    if (imageWidth) {
        x = imageRect.origin.x / (double)imageWidth;
        width = imageRect.size.width / (double)imageWidth;
    }
    if (imageHeight) {
        y = imageRect.origin.y / (double)imageHeight;
        height = imageRect.size.height / (double)imageHeight;
    }
    return CGRectMake(x, y, width, height);
}

CGPoint BACKPORT_IMPL(VNNormalizedFaceBoundingBoxPointForLandmarkPoint)(vector_float2 faceLandmarkPoint, CGRect faceBoundingBox, size_t imageWidth, size_t imageHeight)
{
    return CGPointMake(faceBoundingBox.size.width * (double)imageWidth * (double)faceLandmarkPoint.x, faceBoundingBox.size.height * (double)imageHeight * (double)faceLandmarkPoint.y);
}

CGPoint BACKPORT_IMPL(VNImagePointForFaceLandmarkPoint)(vector_float2 faceLandmarkPoint, CGRect faceBoundingBox, size_t imageWidth, size_t imageHeight)
{
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGPointMake(faceBoundingBox.origin.x * width + faceBoundingBox.size.width * width * (double)faceLandmarkPoint.x,
                       faceBoundingBox.origin.y * height + faceBoundingBox.size.height * height * (double)faceLandmarkPoint.y);
}
