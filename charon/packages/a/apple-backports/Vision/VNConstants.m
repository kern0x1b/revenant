#import <Vision/Vision.h>

/* The domain every Vision error is in, measured from the Vision of this host: com.apple.Vision.
 * A port that answered com.apple.vis would be answering in a domain no release has ever used, and
 * an application that switches on the domain of a Vision error -- which is how a caller tells a
 * Vision failure from any other -- would take the other branch. */
NSString *const VNErrorDomain = @"com.apple.Vision";

VNImageOption const VNImageOptionProperties = @"VNImageOptionProperties";
VNImageOption const VNImageOptionCameraIntrinsics = @"VNImageOptionCameraIntrinsics";
VNImageOption const VNImageOptionCIContext = @"VNImageOptionCIContext";

VNBarcodeSymbology const VNBarcodeSymbologyAztec = @"VNBarcodeSymbologyAztec";
VNBarcodeSymbology const VNBarcodeSymbologyCode39 = @"VNBarcodeSymbologyCode39";
VNBarcodeSymbology const VNBarcodeSymbologyCode39Checksum = @"VNBarcodeSymbologyCode39Checksum";
VNBarcodeSymbology const VNBarcodeSymbologyCode39FullASCII = @"VNBarcodeSymbologyCode39FullASCII";
VNBarcodeSymbology const VNBarcodeSymbologyCode39FullASCIIChecksum = @"VNBarcodeSymbologyCode39FullASCIIChecksum";
VNBarcodeSymbology const VNBarcodeSymbologyCode93 = @"VNBarcodeSymbologyCode93";
VNBarcodeSymbology const VNBarcodeSymbologyCode93i = @"VNBarcodeSymbologyCode93i";
VNBarcodeSymbology const VNBarcodeSymbologyCode128 = @"VNBarcodeSymbologyCode128";
VNBarcodeSymbology const VNBarcodeSymbologyDataMatrix = @"VNBarcodeSymbologyDataMatrix";
VNBarcodeSymbology const VNBarcodeSymbologyEAN8 = @"VNBarcodeSymbologyEAN8";
VNBarcodeSymbology const VNBarcodeSymbologyEAN13 = @"VNBarcodeSymbologyEAN13";
VNBarcodeSymbology const VNBarcodeSymbologyI2of5 = @"VNBarcodeSymbologyI2of5";
VNBarcodeSymbology const VNBarcodeSymbologyI2of5Checksum = @"VNBarcodeSymbologyI2of5Checksum";
VNBarcodeSymbology const VNBarcodeSymbologyITF14 = @"VNBarcodeSymbologyITF14";
VNBarcodeSymbology const VNBarcodeSymbologyPDF417 = @"VNBarcodeSymbologyPDF417";
VNBarcodeSymbology const VNBarcodeSymbologyQR = @"VNBarcodeSymbologyQR";
VNBarcodeSymbology const VNBarcodeSymbologyUPCE = @"VNBarcodeSymbologyUPCE";

const CGRect VNNormalizedIdentityRect = {{0, 0}, {1, 1}};
double VNVisionVersionNumber = 2.0;

bool VNNormalizedRectIsIdentityRect(CGRect normalizedRect)
{
    return CGRectEqualToRect(normalizedRect, CGRectMake(0, 0, 1, 1));
}

CGPoint VNImagePointForNormalizedPoint(CGPoint normalizedPoint, size_t imageWidth, size_t imageHeight)
{
    return CGPointMake(normalizedPoint.x * (double)imageWidth, normalizedPoint.y * (double)imageHeight);
}

CGRect VNImageRectForNormalizedRect(CGRect normalizedRect, size_t imageWidth, size_t imageHeight)
{
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGRectMake(normalizedRect.origin.x * width, normalizedRect.origin.y * height, normalizedRect.size.width * width, normalizedRect.size.height * height);
}

CGRect VNNormalizedRectForImageRect(CGRect imageRect, size_t imageWidth, size_t imageHeight)
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

CGPoint VNNormalizedFaceBoundingBoxPointForLandmarkPoint(vector_float2 faceLandmarkPoint, CGRect faceBoundingBox, size_t imageWidth, size_t imageHeight)
{
    return CGPointMake(faceBoundingBox.size.width * (double)imageWidth * (double)faceLandmarkPoint.x, faceBoundingBox.size.height * (double)imageHeight * (double)faceLandmarkPoint.y);
}

CGPoint VNImagePointForFaceLandmarkPoint(vector_float2 faceLandmarkPoint, CGRect faceBoundingBox, size_t imageWidth, size_t imageHeight)
{
    double width = (double)imageWidth, height = (double)imageHeight;
    return CGPointMake(faceBoundingBox.origin.x * width + faceBoundingBox.size.width * width * (double)faceLandmarkPoint.x,
                       faceBoundingBox.origin.y * height + faceBoundingBox.size.height * height * (double)faceLandmarkPoint.y);
}
