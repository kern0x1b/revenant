// AVDepthData11.m - AVDepthData and AVCameraCalibrationData as of 11.0, in one object because they are one
// release's API: the depth map an application reads off a capture and the calibration that comes with it.
//
// Neither class is on 6.1.3, and neither is anything a 6.1.3 capture produces: this port's cameras deliver
// no depth (AVCaptureDeviceFormat.supportedDepthDataFormats is empty on every device of the port), so the
// classes here are the value objects an application builds from its own bytes, and the ones this port
// hands out when a depth dictionary is read. Every answer below is the one the host's own AVFoundation gives
// for the same input, measured by tests/backports/host/avf-depthdata (the same probe, against this Mac's
// framework and against this file renamed), and what the host does not measure is named where it is written.
//
// THE FORMAT OF A DEPTH MAP is the pixel format of its CVPixelBuffer, one of four: DisparityFloat16,
// DisparityFloat32, DepthFloat16 and DepthFloat32. A disparity and a depth of the same precision hold the
// same numbers the other way round, and the host's conversion is depth = 1 / disparity, computed in
// single precision and stored at the precision of the target (measured: 0.5 -> 2, 2 -> 0.5, 0.25 -> 4 in both
// directions; the float16 targets round to nearest, 2.0 -> 0x4000 and 0.5 -> 0x3800).
//
// THE DICTIONARY IS THE HOST'S OWN SHAPE. kCGImageAuxiliaryDataInfoData carries the map's bytes, one row after
// another at the stride kCGImageAuxiliaryDataInfoDataDescription names; the description's Width, Height,
// BytesPerRow and PixelFormat are read here; and kCGImageAuxiliaryDataInfoMetadata carries the three depth
// facts (quality, accuracy, filtering) as the host writes them. The key strings are the values the host's
// dictionaries carry (measured: the three keys and the two type names, kCGImageAuxiliaryDataTypeDisparity and
// kCGImageAuxiliaryDataTypeDepth), and they are spelled here as strings because ImageIO on 6.1.3 exports no
// symbol for them.
//
// THE ONE DIFFERENCE, named: the host's metadata value is a CGImageMetadata object, and 6.1.3's ImageIO has no
// such type to return. The port writes the same three facts as the text the host's object prints, so the
// dictionary round-trips and the facts read back the same; a caller that casts the value to CGImageMetadata
// gets a string instead. facts/AVFoundation/DepthData11.md has the measurements.
//
// THE CALIBRATION is not read from any dictionary this port receives: the host's depth dictionaries carry none,
// and no capture on the port's hardware delivers one. An AVCameraCalibrationData therefore has the values
// -init gives it, which are the zero values of every field, and an AVDepthData's cameraCalibrationData is nil
// unless a value was set through the same class. facts/AVFoundation/DepthData11.md, "Calibration", says what
// a calibrated map would need.
#import <AVFoundation/AVDepthData.h>
#import <AVFoundation/AVError.h>
#import <AVFoundation/AVCameraCalibrationData.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

// The keys of the auxiliary dictionary, as the host spells them. See the note above.
static NSString *const CharonAuxInfoData = @"kCGImageAuxiliaryDataInfoData";
static NSString *const CharonAuxInfoDataDescription = @"kCGImageAuxiliaryDataInfoDataDescription";
static NSString *const CharonAuxInfoMetadata = @"kCGImageAuxiliaryDataInfoMetadata";
static NSString *const CharonAuxTypeDisparity = @"kCGImageAuxiliaryDataTypeDisparity";
static NSString *const CharonAuxTypeDepth = @"kCGImageAuxiliaryDataTypeDepth";

// The two errors a dictionary can fail with, by the codes the host returns (AVFoundationErrorDomain, measured:
// an empty dictionary is -11865 "Depth is malformed", a PixelFormat that is no depth format is -11864
// "Format Unsupported"). The header's own AVError codes are the same numbers; the port names them here so that
// the one place that raises them says which.
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

// The value of one pixel, read at its format's precision. A half float is read through __fp16, which is the
// compiler's own half type, so the rounding is the platform's and not a second one written here.
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

// Converting a pixel across the disparity and depth families yields its reciprocal, capped by the host's own
// behaviour: input at or below zero, or a reciprocal past 10000, reads back as 10000 (measured on the host in both
// directions: 0, -2 and 1e-6 all answer 10000, and 70000 answers 1/70000 at either precision).
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

// A new depth buffer of one format and size. Its rows are the buffer's own stride; nothing is assumed about it.
static CVPixelBufferRef CharonCreateDepthBuffer(size_t width, size_t height, OSType format)
{
    CVPixelBufferRef buffer = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, NULL, &buffer) != kCVReturnSuccess)
        return NULL;
    return buffer;
}

// The three facts the metadata carries, read from its text. A value the text does not name keeps the default
// the host gives a dictionary without metadata (quality low, accuracy relative, not filtered).
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

// An object no camera made: every field is the zero value of its type. The host's private -_initEmpty makes the same
// zeros (measured on macOS 27.0.1); the public -init is unavailable there and segfaults. No public path on 6.1.3 makes
// such an object, and the calibration paths of this port are absent until a depth file carries one (see the notes
// above and facts/AVFoundation/DepthData11.md, "Calibration").
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

// The one place a depth data object is made: every factory and conversion below builds through it, so the
// buffer is retained once and the facts travel together.
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
    // The four formats in the host's order: a disparity and a depth, each at both precisions.
    return @[ @(kCVPixelFormatType_DisparityFloat16), @(kCVPixelFormatType_DisparityFloat32),
              @(kCVPixelFormatType_DepthFloat16), @(kCVPixelFormatType_DepthFloat32) ];
}

- (AVDepthData *)depthDataByConvertingToDepthDataType:(OSType)depthDataType
{
    // A target that is no depth format has no conversion: the host raises an invalid-argument exception with this reason.
    if (!CharonIsDepthFormat(depthDataType))
        [NSException raise:NSInvalidArgumentException
                    format:@"*** -[AVDepthData depthDataByConvertingToDepthDataType:] Unsupported depth data type"];
    size_t w = CVPixelBufferGetWidth(_depthDataMap), h = CVPixelBufferGetHeight(_depthDataMap);
    CVPixelBufferRef converted = CharonCreateDepthBuffer(w, h, depthDataType);
    if (!converted)
        return nil;
    // The same family keeps its values; the other family takes the reciprocal, the host's own conversion.
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

// The eight EXIF orientations, measured on a 2x2 map (the host's own answer for each): 1 is the identity, 2 mirrors
// across the vertical axis, 3 turns half a circle, 4 mirrors across the horizontal axis, 5 transposes, 6 turns a
// quarter clockwise, 7 is the anti-transpose and 8 turns a quarter counter-clockwise. The output of 5 to 8 has the
// input's rows and columns exchanged.
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
    // The map keeps its format: a buffer of another one is refused, as the host refuses a BGRA buffer.
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
