#import <AVFoundation/AVDepthData.h>
#import <AVFoundation/AVError.h>
#import <AVFoundation/AVCameraCalibrationData.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

static NSString *const RevenantAuxInfoData = @"kCGImageAuxiliaryDataInfoData";
static NSString *const RevenantAuxInfoDataDescription = @"kCGImageAuxiliaryDataInfoDataDescription";
static NSString *const RevenantAuxInfoMetadata = @"kCGImageAuxiliaryDataInfoMetadata";
static NSString *const RevenantAuxTypeDisparity = @"kCGImageAuxiliaryDataTypeDisparity";
static NSString *const RevenantAuxTypeDepth = @"kCGImageAuxiliaryDataTypeDepth";

static const NSInteger RevenantDepthFormatUnsupported = -11864;
static const NSInteger RevenantDepthMalformed = -11865;

static BOOL RevenantIsDepthFormat(OSType format)
{
    return format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DisparityFloat32 ||
           format == kCVPixelFormatType_DepthFloat16 || format == kCVPixelFormatType_DepthFloat32;
}

static BOOL RevenantIsDisparityFormat(OSType format)
{
    return format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DisparityFloat32;
}

static BOOL RevenantIsHalfFormat(OSType format)
{
    return format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DepthFloat16;
}

static float RevenantReadPixel(const unsigned char *pixel, OSType format)
{
    if (RevenantIsHalfFormat(format)) {
        __fp16 value;
        memcpy(&value, pixel, sizeof value);
        return (float)value;
    }
    float value;
    memcpy(&value, pixel, sizeof value);
    return value;
}

static void RevenantWritePixel(unsigned char *pixel, OSType format, float value)
{
    if (RevenantIsHalfFormat(format)) {
        __fp16 half = (__fp16)value;
        memcpy(pixel, &half, sizeof half);
        return;
    }
    memcpy(pixel, &value, sizeof value);
}

static float RevenantReciprocal(float value)
{
    const float limit = 10000.0f;
    if (!(value > 0))
        return limit;
    float reciprocal = 1.0f / value;
    return reciprocal < limit ? reciprocal : limit;
}

static size_t RevenantBytesPerPixel(OSType format)
{
    return RevenantIsHalfFormat(format) ? 2 : 4;
}

static CVPixelBufferRef RevenantCreateDepthBuffer(size_t width, size_t height, OSType format)
{
    CVPixelBufferRef buffer = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, NULL, &buffer) != kCVReturnSuccess)
        return NULL;
    return buffer;
}

static void RevenantReadMetadata(NSString *text, AVDepthDataQuality *quality, AVDepthDataAccuracy *accuracy, BOOL *filtered)
{
    for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSRange equals = [line rangeOfString:@"="];
        if (equals.location == NSNotFound)
            continue;
        NSString *name = [[line substringToIndex:equals.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *value = [[line substringFromIndex:equals.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([name isEqualToString:@"depthData:Quality"])
            *quality = [value isEqualToString:@"high"] ? AVDepthDataQualityHigh : AVDepthDataQualityLow;
        else if ([name isEqualToString:@"depthData:Accuracy"])
            *accuracy = [value isEqualToString:@"absolute"] ? AVDepthDataAccuracyAbsolute : AVDepthDataAccuracyRelative;
        else if ([name isEqualToString:@"depthData:Filtered"])
            *filtered = [value caseInsensitiveCompare:@"True"] == NSOrderedSame;
    }
}

static NSString *RevenantMetadataText(AVDepthDataQuality quality, AVDepthDataAccuracy accuracy, BOOL filtered)
{
    return [NSString stringWithFormat:@"depthData:Quality = %@\ndepthData:Filtered = %@\ndepthData:Accuracy = %@\n",
            quality == AVDepthDataQualityHigh ? @"high" : @"low",
            filtered ? @"True" : @"False",
            accuracy == AVDepthDataAccuracyAbsolute ? @"absolute" : @"relative"];
}

@implementation AVCameraCalibrationData

- (matrix_float3x3)intrinsicMatrix
{
    matrix_float3x3 zero;
    memset(&zero, 0, sizeof zero);
    return zero;
}

- (CGSize)intrinsicMatrixReferenceDimensions
{
    return CGSizeZero;
}

- (matrix_float4x3)extrinsicMatrix
{
    matrix_float4x3 zero;
    memset(&zero, 0, sizeof zero);
    return zero;
}

- (float)pixelSize
{
    return 0;
}

- (NSData *)lensDistortionLookupTable
{
    return nil;
}

- (NSData *)inverseLensDistortionLookupTable
{
    return nil;
}

- (CGPoint)lensDistortionCenter
{
    return CGPointZero;
}

@end

@implementation AVDepthData {
    CVPixelBufferRef _depthDataMap;
    OSType _depthDataType;
    AVDepthDataQuality _depthDataQuality;
    AVDepthDataAccuracy _depthDataAccuracy;
    BOOL _depthDataFiltered;
    AVCameraCalibrationData *_cameraCalibrationData;
}

- (void)dealloc
{
    if (_depthDataMap)
        CVPixelBufferRelease(_depthDataMap);
}

- (instancetype)initWithMap:(CVPixelBufferRef)map quality:(AVDepthDataQuality)quality accuracy:(AVDepthDataAccuracy)accuracy
                          filtered:(BOOL)filtered calibration:(AVCameraCalibrationData *)calibration
{
    if ((self = [super init])) {
        _depthDataMap = CVPixelBufferRetain(map);
        _depthDataType = CVPixelBufferGetPixelFormatType(map);
        _depthDataQuality = quality;
        _depthDataAccuracy = accuracy;
        _depthDataFiltered = filtered;
        _cameraCalibrationData = calibration;
    }
    return self;
}

+ (AVDepthData *)depthDataFromDictionaryRepresentation:(NSDictionary *)dictionary error:(NSError **)outError
{
    NSData *bytes = [dictionary isKindOfClass:[NSDictionary class]] ? dictionary[RevenantAuxInfoData] : nil;
    NSDictionary *description = [dictionary isKindOfClass:[NSDictionary class]] ? dictionary[RevenantAuxInfoDataDescription] : nil;
    if (![bytes isKindOfClass:[NSData class]] || ![description isKindOfClass:[NSDictionary class]]) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:RevenantDepthMalformed
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Depth is malformed" }];
        return nil;
    }
    NSNumber *width = description[@"Width"], *height = description[@"Height"];
    NSNumber *bytesPerRow = description[@"BytesPerRow"], *pixelFormat = description[@"PixelFormat"];
    if (![width isKindOfClass:[NSNumber class]] || ![height isKindOfClass:[NSNumber class]] ||
        ![bytesPerRow isKindOfClass:[NSNumber class]] || ![pixelFormat isKindOfClass:[NSNumber class]]) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:RevenantDepthMalformed
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Depth is malformed" }];
        return nil;
    }
    OSType format = (OSType)pixelFormat.unsignedIntValue;
    if (!RevenantIsDepthFormat(format)) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:RevenantDepthFormatUnsupported
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Format Unsupported" }];
        return nil;
    }
    size_t w = width.unsignedIntegerValue, h = height.unsignedIntegerValue, stride = bytesPerRow.unsignedIntegerValue;
    size_t rowBytes = w * RevenantBytesPerPixel(format);
    if (w == 0 || h == 0 || stride < rowBytes || bytes.length < stride * (h - 1) + rowBytes) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:RevenantDepthMalformed
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Depth is malformed" }];
        return nil;
    }
    CVPixelBufferRef map = RevenantCreateDepthBuffer(w, h, format);
    if (!map) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:RevenantDepthFormatUnsupported
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Format Unsupported" }];
        return nil;
    }
    CVPixelBufferLockBaseAddress(map, 0);
    const unsigned char *source = bytes.bytes;
    unsigned char *target = CVPixelBufferGetBaseAddress(map);
    size_t targetStride = CVPixelBufferGetBytesPerRow(map);
    for (size_t y = 0; y < h; y++)
        memcpy(target + y * targetStride, source + y * stride, rowBytes);
    CVPixelBufferUnlockBaseAddress(map, 0);

    AVDepthDataQuality quality = AVDepthDataQualityLow;
    AVDepthDataAccuracy accuracy = AVDepthDataAccuracyRelative;
    BOOL filtered = NO;
    id metadata = dictionary[RevenantAuxInfoMetadata];
    if ([metadata isKindOfClass:[NSString class]])
        RevenantReadMetadata(metadata, &quality, &accuracy, &filtered);
    AVDepthData *depth = [[AVDepthData alloc] initWithMap:map quality:quality accuracy:accuracy filtered:filtered calibration:nil];
    CVPixelBufferRelease(map);
    return depth;
}

- (NSArray<NSNumber *> *)availableDepthDataTypes
{
    return @[ @(kCVPixelFormatType_DisparityFloat16), @(kCVPixelFormatType_DisparityFloat32),
              @(kCVPixelFormatType_DepthFloat16), @(kCVPixelFormatType_DepthFloat32) ];
}

- (AVDepthData *)depthDataByConvertingToDepthDataType:(OSType)depthDataType
{
    if (!RevenantIsDepthFormat(depthDataType))
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVDepthData depthDataByConvertingToDepthDataType:] Unsupported depth data type"];
    size_t w = CVPixelBufferGetWidth(_depthDataMap), h = CVPixelBufferGetHeight(_depthDataMap);
    CVPixelBufferRef converted = RevenantCreateDepthBuffer(w, h, depthDataType);
    if (!converted)
        return nil;
    BOOL invert = RevenantIsDisparityFormat(_depthDataType) != RevenantIsDisparityFormat(depthDataType);
    CVPixelBufferLockBaseAddress(_depthDataMap, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(converted, 0);
    const unsigned char *source = CVPixelBufferGetBaseAddress(_depthDataMap);
    unsigned char *target = CVPixelBufferGetBaseAddress(converted);
    size_t sourceStride = CVPixelBufferGetBytesPerRow(_depthDataMap), targetStride = CVPixelBufferGetBytesPerRow(converted);
    size_t sourceBytes = RevenantBytesPerPixel(_depthDataType), targetBytes = RevenantBytesPerPixel(depthDataType);
    for (size_t y = 0; y < h; y++)
        for (size_t x = 0; x < w; x++) {
            float value = RevenantReadPixel(source + y * sourceStride + x * sourceBytes, _depthDataType);
            if (invert)
                value = RevenantReciprocal(value);
            RevenantWritePixel(target + y * targetStride + x * targetBytes, depthDataType, value);
        }
    CVPixelBufferUnlockBaseAddress(converted, 0);
    CVPixelBufferUnlockBaseAddress(_depthDataMap, kCVPixelBufferLock_ReadOnly);
    AVDepthData *result = [[AVDepthData alloc] initWithMap:converted quality:_depthDataQuality accuracy:_depthDataAccuracy
                                                         filtered:_depthDataFiltered calibration:_cameraCalibrationData];
    CVPixelBufferRelease(converted);
    return result;
}

- (AVDepthData *)depthDataByApplyingExifOrientation:(CGImagePropertyOrientation)orientation
{
    size_t w = CVPixelBufferGetWidth(_depthDataMap), h = CVPixelBufferGetHeight(_depthDataMap);
    BOOL swaps = orientation >= kCGImagePropertyOrientationLeftMirrored;
    size_t outW = swaps ? h : w, outH = swaps ? w : h;
    CVPixelBufferRef rotated = RevenantCreateDepthBuffer(outW, outH, _depthDataType);
    if (!rotated)
        return nil;
    CVPixelBufferLockBaseAddress(_depthDataMap, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(rotated, 0);
    const unsigned char *source = CVPixelBufferGetBaseAddress(_depthDataMap);
    unsigned char *target = CVPixelBufferGetBaseAddress(rotated);
    size_t sourceStride = CVPixelBufferGetBytesPerRow(_depthDataMap), targetStride = CVPixelBufferGetBytesPerRow(rotated);
    size_t pixel = RevenantBytesPerPixel(_depthDataType);
    for (size_t r = 0; r < outH; r++)
        for (size_t c = 0; c < outW; c++) {
            size_t sr = r, sc = c;
            switch (orientation) {
                case kCGImagePropertyOrientationUp: break;
                case kCGImagePropertyOrientationUpMirrored: sc = w - 1 - c; break;
                case kCGImagePropertyOrientationDown: sr = h - 1 - r; sc = w - 1 - c; break;
                case kCGImagePropertyOrientationDownMirrored: sr = h - 1 - r; break;
                case kCGImagePropertyOrientationLeftMirrored: sr = c; sc = r; break;
                case kCGImagePropertyOrientationRight: sr = h - 1 - c; sc = r; break;
                case kCGImagePropertyOrientationRightMirrored: sr = h - 1 - c; sc = w - 1 - r; break;
                case kCGImagePropertyOrientationLeft: sr = c; sc = w - 1 - r; break;
            }
            memcpy(target + r * targetStride + c * pixel, source + sr * sourceStride + sc * pixel, pixel);
        }
    CVPixelBufferUnlockBaseAddress(rotated, 0);
    CVPixelBufferUnlockBaseAddress(_depthDataMap, kCVPixelBufferLock_ReadOnly);
    AVDepthData *result = [[AVDepthData alloc] initWithMap:rotated quality:_depthDataQuality accuracy:_depthDataAccuracy
                                                         filtered:_depthDataFiltered calibration:_cameraCalibrationData];
    CVPixelBufferRelease(rotated);
    return result;
}

- (AVDepthData *)depthDataByReplacingDepthDataMapWithPixelBuffer:(CVPixelBufferRef)depthDataMap error:(NSError **)outError
{
    if (CVPixelBufferGetPixelFormatType(depthDataMap) != _depthDataType) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:RevenantDepthFormatUnsupported
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Format Unsupported" }];
        return nil;
    }
    return [[AVDepthData alloc] initWithMap:depthDataMap quality:_depthDataQuality accuracy:_depthDataAccuracy
                                          filtered:_depthDataFiltered calibration:_cameraCalibrationData];
}

- (NSDictionary *)dictionaryRepresentationForAuxiliaryDataType:(NSString **)outAuxDataType
{
    size_t w = CVPixelBufferGetWidth(_depthDataMap), h = CVPixelBufferGetHeight(_depthDataMap);
    size_t stride = CVPixelBufferGetBytesPerRow(_depthDataMap);
    CVPixelBufferLockBaseAddress(_depthDataMap, kCVPixelBufferLock_ReadOnly);
    NSData *bytes = [NSData dataWithBytes:CVPixelBufferGetBaseAddress(_depthDataMap) length:stride * h];
    CVPixelBufferUnlockBaseAddress(_depthDataMap, kCVPixelBufferLock_ReadOnly);
    if (outAuxDataType)
        *outAuxDataType = RevenantIsDisparityFormat(_depthDataType) ? RevenantAuxTypeDisparity : RevenantAuxTypeDepth;
    return @{
        RevenantAuxInfoData: bytes,
        RevenantAuxInfoDataDescription: @{ @"Width": @(w), @"Height": @(h), @"BytesPerRow": @(stride), @"PixelFormat": @(_depthDataType) },
        RevenantAuxInfoMetadata: RevenantMetadataText(_depthDataQuality, _depthDataAccuracy, _depthDataFiltered),
    };
}

- (CVPixelBufferRef)depthDataMap
{
    return _depthDataMap;
}

- (OSType)depthDataType
{
    return _depthDataType;
}

- (AVDepthDataQuality)depthDataQuality
{
    return _depthDataQuality;
}

- (AVDepthDataAccuracy)depthDataAccuracy
{
    return _depthDataAccuracy;
}

- (BOOL)depthDataFiltered
{
    return _depthDataFiltered;
}

- (AVCameraCalibrationData *)cameraCalibrationData
{
    return _cameraCalibrationData;
}

@end
