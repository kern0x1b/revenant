#import <AVFoundation/AVDepthData.h>
#import <AVFoundation/AVError.h>
#import <AVFoundation/AVCameraCalibrationData.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

static NSString *const CharonAuxInfoData = @"kCGImageAuxiliaryDataInfoData";
static NSString *const CharonAuxInfoDataDescription = @"kCGImageAuxiliaryDataInfoDataDescription";
static NSString *const CharonAuxInfoMetadata = @"kCGImageAuxiliaryDataInfoMetadata";
static NSString *const CharonAuxTypeDisparity = @"kCGImageAuxiliaryDataTypeDisparity";
static NSString *const CharonAuxTypeDepth = @"kCGImageAuxiliaryDataTypeDepth";

static const NSInteger CharonDepthFormatUnsupported = -11864;
static const NSInteger CharonDepthMalformed = -11865;

static BOOL CharonIsDepthFormat(OSType format)
{
    return format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DisparityFloat32 ||
           format == kCVPixelFormatType_DepthFloat16 || format == kCVPixelFormatType_DepthFloat32;
}

static BOOL CharonIsDisparityFormat(OSType format)
{
    return format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DisparityFloat32;
}

static BOOL CharonIsHalfFormat(OSType format)
{
    return format == kCVPixelFormatType_DisparityFloat16 || format == kCVPixelFormatType_DepthFloat16;
}

static float CharonReadPixel(const unsigned char *pixel, OSType format)
{
    if (CharonIsHalfFormat(format)) {
        __fp16 value;
        memcpy(&value, pixel, sizeof value);
        return (float)value;
    }
    float value;
    memcpy(&value, pixel, sizeof value);
    return value;
}

static void CharonWritePixel(unsigned char *pixel, OSType format, float value)
{
    if (CharonIsHalfFormat(format)) {
        __fp16 half = (__fp16)value;
        memcpy(pixel, &half, sizeof half);
        return;
    }
    memcpy(pixel, &value, sizeof value);
}

static float CharonReciprocal(float value)
{
    const float limit = 10000.0f;
    if (!(value > 0))
        return limit;
    float reciprocal = 1.0f / value;
    return reciprocal < limit ? reciprocal : limit;
}

static size_t CharonBytesPerPixel(OSType format)
{
    return CharonIsHalfFormat(format) ? 2 : 4;
}

static CVPixelBufferRef CharonCreateDepthBuffer(size_t width, size_t height, OSType format)
{
    CVPixelBufferRef buffer = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, NULL, &buffer) != kCVReturnSuccess)
        return NULL;
    return buffer;
}

static void CharonReadMetadata(NSString *text, AVDepthDataQuality *quality, AVDepthDataAccuracy *accuracy, BOOL *filtered)
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

static NSString *CharonMetadataText(AVDepthDataQuality quality, AVDepthDataAccuracy accuracy, BOOL filtered)
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
    NSData *bytes = [dictionary isKindOfClass:[NSDictionary class]] ? dictionary[CharonAuxInfoData] : nil;
    NSDictionary *description = [dictionary isKindOfClass:[NSDictionary class]] ? dictionary[CharonAuxInfoDataDescription] : nil;
    if (![bytes isKindOfClass:[NSData class]] || ![description isKindOfClass:[NSDictionary class]]) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:CharonDepthMalformed
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Depth is malformed" }];
        return nil;
    }
    NSNumber *width = description[@"Width"], *height = description[@"Height"];
    NSNumber *bytesPerRow = description[@"BytesPerRow"], *pixelFormat = description[@"PixelFormat"];
    if (![width isKindOfClass:[NSNumber class]] || ![height isKindOfClass:[NSNumber class]] ||
        ![bytesPerRow isKindOfClass:[NSNumber class]] || ![pixelFormat isKindOfClass:[NSNumber class]]) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:CharonDepthMalformed
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Depth is malformed" }];
        return nil;
    }
    OSType format = (OSType)pixelFormat.unsignedIntValue;
    if (!CharonIsDepthFormat(format)) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:CharonDepthFormatUnsupported
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Format Unsupported" }];
        return nil;
    }
    size_t w = width.unsignedIntegerValue, h = height.unsignedIntegerValue, stride = bytesPerRow.unsignedIntegerValue;
    size_t rowBytes = w * CharonBytesPerPixel(format);
    if (w == 0 || h == 0 || stride < rowBytes || bytes.length < stride * (h - 1) + rowBytes) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:CharonDepthMalformed
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Depth is malformed" }];
        return nil;
    }
    CVPixelBufferRef map = CharonCreateDepthBuffer(w, h, format);
    if (!map) {
        if (outError)
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:CharonDepthFormatUnsupported
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
    id metadata = dictionary[CharonAuxInfoMetadata];
    if ([metadata isKindOfClass:[NSString class]])
        CharonReadMetadata(metadata, &quality, &accuracy, &filtered);
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
    if (!CharonIsDepthFormat(depthDataType))
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVDepthData depthDataByConvertingToDepthDataType:] Unsupported depth data type"];
    size_t w = CVPixelBufferGetWidth(_depthDataMap), h = CVPixelBufferGetHeight(_depthDataMap);
    CVPixelBufferRef converted = CharonCreateDepthBuffer(w, h, depthDataType);
    if (!converted)
        return nil;
    BOOL invert = CharonIsDisparityFormat(_depthDataType) != CharonIsDisparityFormat(depthDataType);
    CVPixelBufferLockBaseAddress(_depthDataMap, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(converted, 0);
    const unsigned char *source = CVPixelBufferGetBaseAddress(_depthDataMap);
    unsigned char *target = CVPixelBufferGetBaseAddress(converted);
    size_t sourceStride = CVPixelBufferGetBytesPerRow(_depthDataMap), targetStride = CVPixelBufferGetBytesPerRow(converted);
    size_t sourceBytes = CharonBytesPerPixel(_depthDataType), targetBytes = CharonBytesPerPixel(depthDataType);
    for (size_t y = 0; y < h; y++)
        for (size_t x = 0; x < w; x++) {
            float value = CharonReadPixel(source + y * sourceStride + x * sourceBytes, _depthDataType);
            if (invert)
                value = CharonReciprocal(value);
            CharonWritePixel(target + y * targetStride + x * targetBytes, depthDataType, value);
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
    CVPixelBufferRef rotated = CharonCreateDepthBuffer(outW, outH, _depthDataType);
    if (!rotated)
        return nil;
    CVPixelBufferLockBaseAddress(_depthDataMap, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(rotated, 0);
    const unsigned char *source = CVPixelBufferGetBaseAddress(_depthDataMap);
    unsigned char *target = CVPixelBufferGetBaseAddress(rotated);
    size_t sourceStride = CVPixelBufferGetBytesPerRow(_depthDataMap), targetStride = CVPixelBufferGetBytesPerRow(rotated);
    size_t pixel = CharonBytesPerPixel(_depthDataType);
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
            *outError = [NSError errorWithDomain:AVFoundationErrorDomain code:CharonDepthFormatUnsupported
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
        *outAuxDataType = CharonIsDisparityFormat(_depthDataType) ? CharonAuxTypeDisparity : CharonAuxTypeDepth;
    return @{
        CharonAuxInfoData: bytes,
        CharonAuxInfoDataDescription: @{ @"Width": @(w), @"Height": @(h), @"BytesPerRow": @(stride), @"PixelFormat": @(_depthDataType) },
        CharonAuxInfoMetadata: CharonMetadataText(_depthDataQuality, _depthDataAccuracy, _depthDataFiltered),
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
