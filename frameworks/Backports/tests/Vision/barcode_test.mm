#import "VNBarcodeDecoder.h"
#import <CoreGraphics/CoreGraphics.h>
#import <ZXing/BitMatrix.h>
#import <ZXing/BarcodeFormat.h>
#import <ZXing/MultiFormatWriter.h>
#include <cmath>
#include <cstring>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

static void check(bool value)
{
    if (!value)
        std::exit(1);
}

static bool negative_control;

static void check_point(NSArray *point)
{
    double x = [point[0] doubleValue];
    double y = [point[1] doubleValue];
    check(std::isfinite(x) && x >= 0 && x <= 1);
    check(std::isfinite(y) && y >= 0 && y <= 1);
}

static void check_barcode(ZXing::BarcodeFormat format, NSString *symbology, const std::string& payload, int width, int height)
{
    ZXing::BitMatrix matrix = ZXing::MultiFormatWriter(format).setMargin(0).encode(payload, width, height);
    std::vector<uint8_t> pixels((size_t)matrix.width() * (size_t)matrix.height());
    for (int y = 0; y < matrix.height(); ++y)
        for (int x = 0; x < matrix.width(); ++x)
            pixels[(size_t)y * (size_t)matrix.width() + (size_t)x] = matrix.get(x, y) ? 0 : 255;
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels.data(), pixels.size(), NULL);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGImageRef image = CGImageCreate(matrix.width(), matrix.height(), 8, 8, matrix.width(), colorSpace, kCGImageAlphaNone,
                                     provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    NSError *error = nil;
    NSArray *observations = RevenantVisionBarcodes((__bridge id)image, kCGImagePropertyOrientationUp,
                                                    @[@"VNBarcodeSymbologyQR", @"VNBarcodeSymbologyPDF417"], &error);
    CGImageRelease(image);
    check(error == nil);
    check((observations.count > 0) != negative_control);
    NSDictionary *observation = observations[0];
    check([observation[@"payload"] isEqualToString:[NSString stringWithUTF8String:payload.c_str()]]);
    check([observation[@"symbology"] isEqualToString:symbology]);
    NSArray *bounds = observation[@"bounds"];
    NSArray *corners = observation[@"corners"];
    check(corners.count == 4);
    for (NSArray *point in corners)
        check_point(point);
    double x = [bounds[0] doubleValue];
    double y = [bounds[1] doubleValue];
    double wide = [bounds[2] doubleValue];
    double high = [bounds[3] doubleValue];
    check(wide > 0 && high > 0 && x >= 0 && y >= 0 && x + wide <= 1.001 && y + high <= 1.001);
    check(std::abs([corners[0][0] doubleValue] - x) < 0.01);
    check(std::abs([corners[0][1] doubleValue] - y - high) < 0.01);
    check(std::abs([corners[1][0] doubleValue] - x - wide) < 0.01);
    check(std::abs([corners[3][1] doubleValue] - y) < 0.01);
}

int main(int argc, char **argv)
{
    negative_control = argc > 1 && std::strcmp(argv[1], "--negative") == 0;
    check_barcode(ZXing::BarcodeFormat::QRCode, @"VNBarcodeSymbologyQR", "revenant-qr-fixture", 256, 256);
    check_barcode(ZXing::BarcodeFormat::PDF417, @"VNBarcodeSymbologyPDF417", "revenant-pdf417-fixture", 320, 160);
}
