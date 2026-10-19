#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

static NSString *const KeyData = @"kCGImageAuxiliaryDataInfoData";
static NSString *const KeyDescription = @"kCGImageAuxiliaryDataInfoDataDescription";

static double readPixel(const unsigned char *p, OSType format)
{
    if (format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DepthFloat16) {
        uint16_t bits;
        memcpy(&bits, p, 2);
        __fp16 half;
        memcpy(&half, &bits, 2);
        return (double)half;
    }
    float value;
    memcpy(&value, p, 4);
    return (double)value;
}

static void printMap(const char *label, CVPixelBufferRef map)
{
    size_t w = CVPixelBufferGetWidth(map), h = CVPixelBufferGetHeight(map);
    OSType format = CVPixelBufferGetPixelFormatType(map);
    size_t bytes = (format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DepthFloat16) ? 2 : 4;
    CVPixelBufferLockBaseAddress(map, kCVPixelBufferLock_ReadOnly);
    const unsigned char *base = CVPixelBufferGetBaseAddress(map);
    size_t stride = CVPixelBufferGetBytesPerRow(map);
    printf("%s map %zux%zu format=%08x:", label, w, h, (unsigned)format);
    for (size_t y = 0; y < h; y++)
        for (size_t x = 0; x < w; x++)
            printf(" %.6g", readPixel(base + y * stride + x * bytes, format));
    printf("\n");
    CVPixelBufferUnlockBaseAddress(map, kCVPixelBufferLock_ReadOnly);
}

static void printDepth(const char *label, AVDepthData *d)
{
    if (!d) {
        printf("%s nil\n", label);
        return;
    }
    printf("%s type=%08x quality=%ld accuracy=%ld filtered=%d calibration=%s\n", label, (unsigned)d.depthDataType,
           (long)d.depthDataQuality, (long)d.depthDataAccuracy, d.depthDataFiltered, d.cameraCalibrationData ? "yes" : "no");
    printMap(label, d.depthDataMap);
}

static NSDictionary *auxDictionary(const float *values, size_t w, size_t h, OSType format)
{
    NSData *bytes;
    if (format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DepthFloat16) {
        uint16_t *bits = calloc(w * h, sizeof(uint16_t));
        for (size_t i = 0; i < w * h; i++) {
            __fp16 half = (__fp16)values[i];
            memcpy(&bits[i], &half, 2);
        }
        bytes = [NSData dataWithBytesNoCopy:bits length:w * h * 2 freeWhenDone:YES];
        return @{ KeyData: bytes, KeyDescription: @{ @"Width": @(w), @"Height": @(h), @"BytesPerRow": @(w * 2), @"PixelFormat": @(format) } };
    }
    bytes = [NSData dataWithBytes:values length:w * h * sizeof(float)];
    return @{ KeyData: bytes, KeyDescription: @{ @"Width": @(w), @"Height": @(h), @"BytesPerRow": @(w * 4), @"PixelFormat": @(format) } };
}

static void printError(const char *label, NSError *error)
{
    printf("%s error domain=%s code=%ld message=%s\n", label, error.domain.UTF8String, (long)error.code,
           error.localizedDescription.UTF8String);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        const float values[6] = { 0.5f, 2.0f, 4.0f, 0.25f, 1.0f, 8.0f };
        NSError *error = nil;

        error = nil;
        printDepth("empty", [AVDepthData depthDataFromDictionaryRepresentation:@{} error:&error]);
        printError("empty", error);
        error = nil;
        NSDictionary *noDescription = @{ KeyData: [NSData dataWithBytes:values length:8] };
        printDepth("no-description", [AVDepthData depthDataFromDictionaryRepresentation:noDescription error:&error]);
        printError("no-description", error);
        error = nil;
        printDepth("unknown-format", [AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(values, 2, 2, 0x12345678) error:&error]);
        printError("unknown-format", error);
        error = nil;
        printDepth("bgra-format", [AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(values, 2, 2, kCVPixelFormatType_32BGRA) error:&error]);
        printError("bgra-format", error);

        OSType formats[4] = { kCVPixelFormatType_DisparityFloat16, kCVPixelFormatType_DisparityFloat32,
                              kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DepthFloat32 };
        const char *names[4] = { "disp16", "disp32", "depth16", "depth32" };
        AVDepthData *sources[4];
        for (int f = 0; f < 4; f++) {
            error = nil;
            sources[f] = [AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(values, 3, 2, formats[f]) error:&error];
            printDepth(names[f], sources[f]);
            printError(names[f], error);
        }

        for (int from = 0; from < 4; from++)
            for (int to = 0; to < 4; to++) {
                char label[32];
                snprintf(label, sizeof label, "%s->%s", names[from], names[to]);
                printDepth(label, [sources[from] depthDataByConvertingToDepthDataType:formats[to]]);
            }
        @try {
            printDepth("convert-to-bgra", [sources[1] depthDataByConvertingToDepthDataType:kCVPixelFormatType_32BGRA]);
        } @catch (NSException *exception) {
            printf("convert-to-bgra raises %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }

        printf("available:");
        for (NSNumber *type in sources[1].availableDepthDataTypes)
            printf(" %08x", type.unsignedIntValue);
        printf("\n");

        for (int o = 1; o <= 8; o++) {
            char label[32];
            snprintf(label, sizeof label, "exif-%d", o);
            printDepth(label, [sources[1] depthDataByApplyingExifOrientation:(CGImagePropertyOrientation)o]);
        }

        CVPixelBufferRef same = NULL, other = NULL;
        CVPixelBufferCreate(NULL, 2, 2, kCVPixelFormatType_DisparityFloat32, NULL, &same);
        CVPixelBufferLockBaseAddress(same, 0);
        for (int y = 0; y < 2; y++)
            for (int x = 0; x < 2; x++)
                ((float *)((unsigned char *)CVPixelBufferGetBaseAddress(same) + y * CVPixelBufferGetBytesPerRow(same)))[x] = 9 - (float)(y * 2 + x);
        CVPixelBufferUnlockBaseAddress(same, 0);
        CVPixelBufferCreate(NULL, 2, 2, kCVPixelFormatType_32BGRA, NULL, &other);
        error = nil;
        printDepth("replaced", [sources[1] depthDataByReplacingDepthDataMapWithPixelBuffer:same error:&error]);
        printError("replaced", error);
        error = nil;
        printDepth("replaced-other", [sources[1] depthDataByReplacingDepthDataMapWithPixelBuffer:other error:&error]);
        printError("replaced-other", error);

        NSString *auxType = nil;
        NSDictionary *back = [sources[3] dictionaryRepresentationForAuxiliaryDataType:&auxType];
        printf("dictionary depth32 type=%s keys=%lu\n", auxType.UTF8String, (unsigned long)back.count);
        NSDictionary *description = back[KeyDescription];
        printf("description width=%s height=%s format=%s\n", [[description[@"Width"] description] UTF8String],
               [[description[@"Height"] description] UTF8String], [[description[@"PixelFormat"] description] UTF8String]);
        auxType = nil;
        NSDictionary *backDisparity = [sources[0] dictionaryRepresentationForAuxiliaryDataType:&auxType];
        printf("dictionary disp16 type=%s keys=%lu\n", auxType.UTF8String, (unsigned long)backDisparity.count);
        AVDepthData *again = [AVDepthData depthDataFromDictionaryRepresentation:back error:NULL];
        printDepth("round-trip depth32", again);

        printf("respond init=%d new=%d\n", [AVCameraCalibrationData instancesRespondToSelector:NSSelectorFromString(@"init")],
               [AVCameraCalibrationData respondsToSelector:NSSelectorFromString(@"new")]);
#ifdef REVENANT_PORT
        SEL zeroSelector = NSSelectorFromString(@"init");
#else
        SEL zeroSelector = NSSelectorFromString(@"_initEmpty");
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        AVCameraCalibrationData *zero = [[AVCameraCalibrationData alloc] performSelector:zeroSelector];
#pragma clang diagnostic pop
        matrix_float3x3 intrinsic = zero.intrinsicMatrix;
        printf("zero-intrinsic");
        for (int c = 0; c < 3; c++) for (int r = 0; r < 3; r++) printf(" %g", intrinsic.columns[c][r]);
        printf("\n");
        CGSize reference = zero.intrinsicMatrixReferenceDimensions;
        printf("zero-reference %g %g\n", reference.width, reference.height);
        matrix_float4x3 extrinsic = zero.extrinsicMatrix;
        printf("zero-extrinsic");
        for (int c = 0; c < 4; c++) for (int r = 0; r < 3; r++) printf(" %g", extrinsic.columns[c][r]);
        printf("\n");
        printf("zero-pixelsize %g\n", zero.pixelSize);
        printf("zero-lut %s inverse=%s\n", zero.lensDistortionLookupTable ? "data" : "nil",
               zero.inverseLensDistortionLookupTable ? "data" : "nil");

        NSMutableDictionary *tagged = [auxDictionary(values, 3, 2, kCVPixelFormatType_DepthFloat32) mutableCopy];
        tagged[@"kCGImageAuxiliaryDataInfoMetadata"] = @"depthData:Quality = high\ndepthData:Filtered = True\ndepthData:Accuracy = absolute\n";
        printDepth("tagged", [AVDepthData depthDataFromDictionaryRepresentation:tagged error:NULL]);
        printDepth("tagged-converted", [[AVDepthData depthDataFromDictionaryRepresentation:tagged error:NULL] depthDataByConvertingToDepthDataType:kCVPixelFormatType_DisparityFloat32]);

        const float edge[4] = { 0.0f, 1.0e-6f, 70000.0f, -2.0f };
        printDepth("edge-disp32", [AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(edge, 4, 1, kCVPixelFormatType_DisparityFloat32) error:NULL]);
        printDepth("edge-depth16", [[AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(edge, 4, 1, kCVPixelFormatType_DisparityFloat32) error:NULL] depthDataByConvertingToDepthDataType:kCVPixelFormatType_DepthFloat16]);
        printDepth("edge-depth32", [[AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(edge, 4, 1, kCVPixelFormatType_DisparityFloat32) error:NULL] depthDataByConvertingToDepthDataType:kCVPixelFormatType_DepthFloat32]);
        printDepth("edge-disp16", [[AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(edge, 4, 1, kCVPixelFormatType_DisparityFloat32) error:NULL] depthDataByConvertingToDepthDataType:kCVPixelFormatType_DisparityFloat16]);
        printDepth("edge-half-depth32", [[AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(edge, 4, 1, kCVPixelFormatType_DisparityFloat16) error:NULL] depthDataByConvertingToDepthDataType:kCVPixelFormatType_DepthFloat32]);

        NSArray *texts = @[ @"depthData:Filtered = True\n", @"depthData:Accuracy = absolute\n", @"depthData:Quality = low\n",
                            @"depthData:Quality = high\ndepthData:Accuracy = absolute\n", @"depthData:Quality = high\n" ];
        for (NSUInteger i = 0; i < texts.count; i++) {
            NSMutableDictionary *variant = [auxDictionary(values, 3, 2, kCVPixelFormatType_DepthFloat32) mutableCopy];
            variant[@"kCGImageAuxiliaryDataInfoMetadata"] = texts[i];
            char label[32];
            snprintf(label, sizeof label, "metadata-%lu", (unsigned long)i);
            printDepth(label, [AVDepthData depthDataFromDictionaryRepresentation:variant error:NULL]);
        }
        const float depthEdge[4] = { 0.0f, 1.0e-6f, 70000.0f, -2.0f };
        AVDepthData *depthEdges = [AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(depthEdge, 4, 1, kCVPixelFormatType_DepthFloat32) error:NULL];
        printDepth("depthedge-depth32", depthEdges);
        printDepth("depthedge-disp32", [depthEdges depthDataByConvertingToDepthDataType:kCVPixelFormatType_DisparityFloat32]);
        printDepth("depthedge-disp16", [depthEdges depthDataByConvertingToDepthDataType:kCVPixelFormatType_DisparityFloat16]);
        const float plain[2] = { 0.5f, 3.0f };
        AVDepthData *bare = [AVDepthData depthDataFromDictionaryRepresentation:auxDictionary(plain, 2, 1, kCVPixelFormatType_DisparityFloat32) error:NULL];
        NSString *bareType = nil;
        NSDictionary *bareBack = [bare dictionaryRepresentationForAuxiliaryDataType:&bareType];
        printf("bare dictionary keys=%lu metadata=%s\n", (unsigned long)bareBack.count, bareBack[@"kCGImageAuxiliaryDataInfoMetadata"] ? "present" : "absent");
        printDepth("bare-reparsed", [AVDepthData depthDataFromDictionaryRepresentation:bareBack error:NULL]);
        printDepth("bare-half", [bare depthDataByConvertingToDepthDataType:kCVPixelFormatType_DisparityFloat16]);
        CVPixelBufferRelease(same);
        CVPixelBufferRelease(other);
    }
    return 0;
}
