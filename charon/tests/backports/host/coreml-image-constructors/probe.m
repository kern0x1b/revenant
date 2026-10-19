#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>

static CGImageRef gradient(size_t wide, size_t high)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, wide, high, 8, wide * 4, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    for (size_t y = 0; y < high; y++) {
        for (size_t x = 0; x < wide; x++) {
            CGContextSetRGBFillColor(context, 40.0 * x / 255.0, 60.0 * y / 255.0, 100.0 / 255.0, 1);
            CGContextFillRect(context, CGRectMake((CGFloat)x, (CGFloat)y, 1, 1));
        }
    }
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return image;
}

static CGImageRef noise(size_t wide, size_t high, uint32_t seed)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, wide, high, 8, wide * 4, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    uint8_t *bytes = CGBitmapContextGetData(context);
    for (size_t i = 0; i < wide * high * 4; i++) {
        seed = seed * 1103515245u + 12345u;
        bytes[i] = (uint8_t)(seed >> 16);
    }
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return image;
}

static void dump(CVPixelBufferRef buffer, OSType format)
{
    size_t wide = CVPixelBufferGetWidth(buffer), high = CVPixelBufferGetHeight(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    const uint8_t *bytes;
    size_t channels = format == kCVPixelFormatType_OneComponent8 ? 1 : 4;
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    bytes = CVPixelBufferGetBaseAddress(buffer);
    printf(" ok %zux%zu:", wide, high);
    for (size_t y = 0; y < high; y++) {
        for (size_t x = 0; x < wide; x++) {
            printf(" ");
            for (size_t c = 0; c < channels; c++) {
                printf("%s%d", c ? "." : "", bytes[y * stride + x * channels + c]);
            }
        }
        printf(" |");
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
}

int main(void)
{
    CGImageRef pictures[2] = {gradient(4, 3), noise(5, 4, 7)};
    const char *pictureNames[2] = {"grad4x3", "noise5x4"};
    NSValue *crops[8];
    const char *cropNames[8] = {"none", "0,0,2,2", "1,0,2,2", "0,0,1,1", "1,0,1,1", "0,0,0,2", "9,9,2,2", "-1,0,2,2"};
    CGRect rects[8] = {CGRectZero, CGRectMake(0, 0, 2, 2), CGRectMake(1, 0, 2, 2), CGRectMake(0, 0, 1, 1),
                       CGRectMake(1, 0, 1, 1), CGRectMake(0, 0, 0, 2), CGRectMake(9, 9, 2, 2), CGRectMake(-1, 0, 2, 2)};
    CGSize sizes[2] = {{2, 2}, {8, 6}};
    OSType formats[3] = {kCVPixelFormatType_32BGRA, kCVPixelFormatType_32ARGB, kCVPixelFormatType_OneComponent8};
    const char *formatNames[3] = {"BGRA", "ARGB", "L008"};
    for (int i = 0; i < 8; i++) {
        crops[i] = [NSValue valueWithRect:NSRectFromCGRect(rects[i])];
    }
    for (int p = 0; p < 2; p++) {
        for (int orientation = 1; orientation <= 8; orientation++) {
            for (int c = 0; c < 8; c++) {
                for (int s = 0; s < 2; s++) {
                    for (int option = -1; option <= 2; option++) {
                        for (int f = 0; f < 3; f++) {
                            NSMutableDictionary *options = [NSMutableDictionary dictionary];
                            if (c > 0) {
                                options[MLFeatureValueImageOptionCropRect] = crops[c];
                            }
                            if (option >= 0) {
                                options[MLFeatureValueImageOptionCropAndScale] = @(option);
                            }
                            NSError *error = nil;
                            MLFeatureValue *value = [MLFeatureValue featureValueWithCGImage:pictures[p]
                                                                                 orientation:orientation
                                                                                  pixelsWide:(NSInteger)sizes[s].width
                                                                                  pixelsHigh:(NSInteger)sizes[s].height
                                                                             pixelFormatType:formats[f]
                                                                                     options:options
                                                                                       error:&error];
                            printf("%s o%d crop=%s size=%.0fx%.0f opt=%s fmt=%s:", pictureNames[p], orientation, cropNames[c],
                                   sizes[s].width, sizes[s].height, option < 0 ? "nil" : (option == 0 ? "0" : (option == 1 ? "1" : "2")),
                                   formatNames[f]);
                            if (value == nil) {
                                printf(" err %ld %s\n", (long)error.code, error.domain.UTF8String);
                            } else {
                                dump(value.imageBufferValue, formats[f]);
                                printf("\n");
                            }
                        }
                    }
                }
            }
        }
    }
    return 0;
}
