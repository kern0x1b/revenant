#import "VNBarcodeDecoder.h"
#import "VNBarcodeDecoderCore.hpp"
#import "VNGrayscale.h"

NSArray *RevenantVisionBarcodes(id image, CGImagePropertyOrientation orientation, NSArray *symbologies, NSError **error)
{
    size_t outputWidth = 0;
    size_t outputHeight = 0;
    NSData *gray = RevenantVisionGrayscale(image, orientation, &outputWidth, &outputHeight, error);
    if (gray == nil)
        return nil;
    std::vector<RevenantBarcodeObservation> decoded = RevenantBarcodeDecode((const uint8_t *)gray.bytes, (int)outputWidth, (int)outputHeight);
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
