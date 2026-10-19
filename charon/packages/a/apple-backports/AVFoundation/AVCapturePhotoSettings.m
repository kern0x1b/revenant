#import "CharonAVCapturePhoto.h"
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>

// AVCapturePhotoSettings, iOS 10.0.1: what one request of AVCapturePhotoOutput asks for. Every member the SDK 16.4
// header declares answers explicitly, with the defaults and the set-time checks of the release's own class, measured
// on the host (facts/AVFoundation/AVCapturePhotoOutput.md, "The photo settings"). What a request asks for is checked
// against the output at -capturePhotoWithSettings:delegate:, as the header's rule list says, and what the release
// cannot capture is refused there, the way a device without the feature refuses it.

// The RAW pixel formats: Bayer, the four 14-bit orders and the versatile 16-bit one; Apple ProRAW, 64-bit RGBA. The
// host's +[AVCapturePhotoOutput isBayerRAWPixelFormat:] and +isAppleProRAWPixelFormat: answer YES for exactly these
// among every pixel format CoreVideo describes (facts).
BOOL CharonIsBayerRAWPixelFormat(OSType format)
{
    switch (format) {
    case kCVPixelFormatType_14Bayer_GRBG:
    case kCVPixelFormatType_14Bayer_RGGB:
    case kCVPixelFormatType_14Bayer_BGGR:
    case kCVPixelFormatType_14Bayer_GBRG:
    case kCVPixelFormatType_16VersatileBayer:
        return YES;
    default:
        return NO;
    }
}

BOOL CharonIsAppleProRAWPixelFormat(OSType format)
{
    return format == kCVPixelFormatType_64RGBALE;
}

static void CharonRaise(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void CharonRaise(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
}

static NSNumber *CharonPixelFormatOf(NSDictionary *format)
{
    id value = format[(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey];
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

static NSString *CharonCodecOf(NSDictionary *format)
{
    id value = format[AVVideoCodecKey];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

// A processed format as the constructors take it: not empty, and exactly one of the two keys (the host's texts).
static void CharonCheckProcessedFormat(NSDictionary *format, NSString *method)
{
    if (!format)
        return;
    if (format.count == 0)
        CharonRaise(@"*** %@ source passthru (empty dictionary) is not supported", method);
    BOOL pixels = CharonPixelFormatOf(format) != nil, codec = CharonCodecOf(format) != nil;
    if (!pixels && !codec)
        CharonRaise(@"*** %@ Either kCVPixelBufferPixelFormatTypeKey or AVVideoCodecKey must be specified", method);
    if (pixels && codec)
        CharonRaise(@"*** %@ kCVPixelBufferPixelFormatTypeKey and AVVideoCodecKey may not both be specified", method);
}

// The file type a processed format is written as when none is given: a JPEG as JPEG, HEVC as HEIC, an uncompressed
// format as TIFF, any other codec none (the host).
static NSString *CharonDefaultProcessedFileType(NSDictionary *format)
{
    NSString *codec = CharonCodecOf(format);
    if (!codec)
        return CharonPixelFormatOf(format) ? AVFileTypeTIFF : nil;
    if ([codec isEqualToString:AVVideoCodecTypeJPEG])
        return AVFileTypeJPEG;
    if ([codec isEqualToString:AVVideoCodecTypeHEVC])
        return AVFileTypeHEIC;
    return nil;
}

// The top-level metadata keys the host's -setMetadata: takes, of every key <ImageIO/CGImageProperties.h> declares:
// the dictionaries of TIFF, Exif, PNG, IPTC, GPS, DNG, ExifAux and MakerApple, and the image's own properties.
static NSSet *CharonMetadataKeys(void)
{
    static NSSet *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = [NSSet setWithObjects:(__bridge NSString *)kCGImagePropertyTIFFDictionary, (__bridge NSString *)kCGImagePropertyExifDictionary,
                                     (__bridge NSString *)kCGImagePropertyPNGDictionary, (__bridge NSString *)kCGImagePropertyIPTCDictionary,
                                     (__bridge NSString *)kCGImagePropertyGPSDictionary, (__bridge NSString *)kCGImagePropertyDNGDictionary,
                                     (__bridge NSString *)kCGImagePropertyExifAuxDictionary, (__bridge NSString *)kCGImagePropertyMakerAppleDictionary,
                                     (__bridge NSString *)kCGImagePropertyFileSize,
                                     (__bridge NSString *)kCGImagePropertyPixelHeight, (__bridge NSString *)kCGImagePropertyPixelWidth,
                                     (__bridge NSString *)kCGImagePropertyDPIHeight, (__bridge NSString *)kCGImagePropertyDPIWidth,
                                     (__bridge NSString *)kCGImagePropertyOrientation, (__bridge NSString *)kCGImagePropertyIsFloat,
                                     (__bridge NSString *)kCGImagePropertyIsIndexed, (__bridge NSString *)kCGImagePropertyHasAlpha,
                                     (__bridge NSString *)kCGImagePropertyColorModel, (__bridge NSString *)kCGImagePropertyProfileName, nil];
    });
    return keys;
}

// The item every settings object carries in its Live Photo movie metadata: its own content identifier, which the
// movie and the photo of one Live Photo share. The application may not give one of its own (the host).
static AVMetadataItem *CharonContentIdentifierItem(NSString *identifier)
{
    AVMutableMetadataItem *item = [AVMutableMetadataItem metadataItem];
    item.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    item.key = AVMetadataQuickTimeMetadataKeyContentIdentifier;
    item.value = identifier;
    return item;
}

static BOOL CharonIsContentIdentifierItem(AVMetadataItem *item)
{
    return [item.keySpace isEqualToString:AVMetadataKeySpaceQuickTimeMetadata] && [(id)item.key isEqual:AVMetadataQuickTimeMetadataKeyContentIdentifier];
}

@implementation AVCapturePhotoSettings
{
    int64_t _charonUniqueID;
    NSDictionary *_charonFormat;
    NSString *_charonProcessedFileType;
    OSType _charonRawPhotoPixelFormatType;
    NSString *_charonRawFileType;
    AVCaptureFlashMode _charonFlashMode;
    BOOL _charonAutoRedEyeReductionEnabled;
    AVCapturePhotoQualityPrioritization _charonPhotoQualityPrioritization;
    BOOL _charonAutoStillImageStabilizationEnabled;
    // autoVirtualDeviceFusionEnabled and the older autoDualCameraFusionEnabled are one setting (the host).
    BOOL _charonAutoVirtualDeviceFusionEnabled;
    NSArray *_charonVirtualDeviceConstituentPhotoDeliveryEnabledDevices;
    BOOL _charonDualCameraDualPhotoDeliveryEnabled;
    BOOL _charonHighResolutionPhotoEnabled;
    CMVideoDimensions _charonMaxPhotoDimensions;
    BOOL _charonDepthDataDeliveryEnabled;
    BOOL _charonEmbedsDepthDataInPhoto;
    BOOL _charonDepthDataFiltered;
    BOOL _charonCameraCalibrationDataDeliveryEnabled;
    BOOL _charonPortraitEffectsMatteDeliveryEnabled;
    BOOL _charonEmbedsPortraitEffectsMatteInPhoto;
    NSArray *_charonEnabledSemanticSegmentationMatteTypes;
    BOOL _charonEmbedsSemanticSegmentationMattesInPhoto;
    NSDictionary *_charonMetadata;
    NSURL *_charonLivePhotoMovieFileURL;
    NSString *_charonLivePhotoVideoCodecType;
    NSString *_charonContentIdentifier;
    NSArray *_charonLivePhotoMovieMetadata;
    NSDictionary *_charonPreviewPhotoFormat;
    NSDictionary *_charonEmbeddedThumbnailPhotoFormat;
    NSDictionary *_charonRawEmbeddedThumbnailPhotoFormat;
    BOOL _charonAutoContentAwareDistortionCorrectionEnabled;
}

+ (int64_t)charon_nextUniqueID
{
    static int64_t counter;
    @synchronized ([AVCapturePhotoSettings class]) {
        return ++counter;
    }
}

// The settings of +photoSettings, under a new unique ID. The header's defaults, as the host answers them, except
// autoStillImageStabilizationEnabled and autoRedEyeReductionEnabled, which the host answers NO: the header gives
// stabilization YES by default, and red-eye reduction YES only where the output supports it, which it does not here.
- (instancetype)init
{
    return [self initCharonWithUniqueID:[AVCapturePhotoSettings charon_nextUniqueID]];
}

- (instancetype)initCharonWithUniqueID:(int64_t)uniqueID
{
    if ((self = [super init])) {
        _charonUniqueID = uniqueID;
        _charonFormat = @{AVVideoCodecKey: AVVideoCodecTypeJPEG};
        _charonProcessedFileType = AVFileTypeJPEG;
        _charonFlashMode = AVCaptureFlashModeOff;
        _charonPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationBalanced;
        _charonAutoStillImageStabilizationEnabled = YES;
        _charonAutoVirtualDeviceFusionEnabled = YES;
        _charonVirtualDeviceConstituentPhotoDeliveryEnabledDevices = @[];
        _charonEmbedsDepthDataInPhoto = YES;
        _charonDepthDataFiltered = YES;
        _charonEmbedsPortraitEffectsMatteInPhoto = YES;
        _charonEnabledSemanticSegmentationMatteTypes = @[];
        _charonEmbedsSemanticSegmentationMattesInPhoto = YES;
        _charonMetadata = @{};
        _charonLivePhotoVideoCodecType = AVVideoCodecTypeH264;
        _charonContentIdentifier = [NSUUID UUID].UUIDString;
        _charonLivePhotoMovieMetadata = @[CharonContentIdentifierItem(_charonContentIdentifier)];
    }
    return self;
}

// The one constructor the others come to: RAW of `raw` (0 for none) written as `rawFileType` (DNG when not given), and
// a processed photo of `format` written as `processedFileType` (the format's own when not given). Nothing is checked
// against an output here; -capturePhotoWithSettings:delegate: does that. With neither RAW nor a format, a JPEG.
+ (instancetype)charon_settingsWithRaw:(OSType)raw rawFileType:(NSString *)rawFileType format:(NSDictionary *)format
                     processedFileType:(NSString *)processedFileType method:(NSString *)method
{
    if (raw && !CharonIsBayerRAWPixelFormat(raw) && !CharonIsAppleProRAWPixelFormat(raw))
        CharonRaise(@"*** %@ Unrecognized raw pixel format type", method);
    CharonCheckProcessedFormat(format, method);
    AVCapturePhotoSettings *settings = [[self alloc] init];
    if (format || !raw) {
        settings->_charonFormat = format ? [format copy] : @{AVVideoCodecKey: AVVideoCodecTypeJPEG};
        settings->_charonProcessedFileType = processedFileType ?: CharonDefaultProcessedFileType(settings->_charonFormat);
    } else {
        settings->_charonFormat = nil;
        settings->_charonProcessedFileType = nil;
    }
    if (raw) {
        settings->_charonRawPhotoPixelFormatType = raw;
        settings->_charonRawFileType = rawFileType ?: AVFileTypeDNG;
        // "YES unless Bayer RAW": a Bayer RAW request is taken at speed, unstabilized and unfused (the header, the host).
        if (CharonIsBayerRAWPixelFormat(raw)) {
            settings->_charonPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationSpeed;
            settings->_charonAutoStillImageStabilizationEnabled = NO;
            settings->_charonAutoVirtualDeviceFusionEnabled = NO;
        }
    }
    return settings;
}

+ (instancetype)photoSettings
{
    return [[self alloc] init];
}

+ (instancetype)photoSettingsWithFormat:(NSDictionary<NSString *, id> *)format
{
    return [self charon_settingsWithRaw:0 rawFileType:nil format:format processedFileType:nil method:@"+[AVCapturePhotoSettings photoSettingsWithFormat:]"];
}

+ (instancetype)photoSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType
{
    return [self charon_settingsWithRaw:rawPixelFormatType rawFileType:nil format:nil processedFileType:nil
                                 method:@"+[AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:]"];
}

+ (instancetype)photoSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType processedFormat:(NSDictionary<NSString *, id> *)processedFormat
{
    return [self charon_settingsWithRaw:rawPixelFormatType rawFileType:nil format:processedFormat processedFileType:nil
                                 method:@"+[AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:processedFormat:]"];
}

+ (instancetype)photoSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType rawFileType:(AVFileType)rawFileType
                                    processedFormat:(NSDictionary<NSString *, id> *)processedFormat processedFileType:(AVFileType)processedFileType
{
    return [self charon_settingsWithRaw:rawPixelFormatType rawFileType:rawFileType format:processedFormat processedFileType:processedFileType
                                 method:@"+[AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:rawFileType:processedFormat:processedFileType:]"];
}

// Every setting of the receiver in a new object of its class under `uniqueID`.
- (instancetype)charon_copyWithZone:(NSZone *)zone uniqueID:(int64_t)uniqueID
{
    AVCapturePhotoSettings *copy = [[[self class] allocWithZone:zone] initCharonWithUniqueID:uniqueID];
    copy->_charonFormat = _charonFormat;
    copy->_charonProcessedFileType = _charonProcessedFileType;
    copy->_charonRawPhotoPixelFormatType = _charonRawPhotoPixelFormatType;
    copy->_charonRawFileType = _charonRawFileType;
    copy->_charonFlashMode = _charonFlashMode;
    copy->_charonAutoRedEyeReductionEnabled = _charonAutoRedEyeReductionEnabled;
    copy->_charonPhotoQualityPrioritization = _charonPhotoQualityPrioritization;
    copy->_charonAutoStillImageStabilizationEnabled = _charonAutoStillImageStabilizationEnabled;
    copy->_charonAutoVirtualDeviceFusionEnabled = _charonAutoVirtualDeviceFusionEnabled;
    copy->_charonVirtualDeviceConstituentPhotoDeliveryEnabledDevices = _charonVirtualDeviceConstituentPhotoDeliveryEnabledDevices;
    copy->_charonDualCameraDualPhotoDeliveryEnabled = _charonDualCameraDualPhotoDeliveryEnabled;
    copy->_charonHighResolutionPhotoEnabled = _charonHighResolutionPhotoEnabled;
    copy->_charonMaxPhotoDimensions = _charonMaxPhotoDimensions;
    copy->_charonDepthDataDeliveryEnabled = _charonDepthDataDeliveryEnabled;
    copy->_charonEmbedsDepthDataInPhoto = _charonEmbedsDepthDataInPhoto;
    copy->_charonDepthDataFiltered = _charonDepthDataFiltered;
    copy->_charonCameraCalibrationDataDeliveryEnabled = _charonCameraCalibrationDataDeliveryEnabled;
    copy->_charonPortraitEffectsMatteDeliveryEnabled = _charonPortraitEffectsMatteDeliveryEnabled;
    copy->_charonEmbedsPortraitEffectsMatteInPhoto = _charonEmbedsPortraitEffectsMatteInPhoto;
    copy->_charonEnabledSemanticSegmentationMatteTypes = _charonEnabledSemanticSegmentationMatteTypes;
    copy->_charonEmbedsSemanticSegmentationMattesInPhoto = _charonEmbedsSemanticSegmentationMattesInPhoto;
    copy->_charonMetadata = _charonMetadata;
    copy->_charonLivePhotoMovieFileURL = _charonLivePhotoMovieFileURL;
    copy->_charonLivePhotoVideoCodecType = _charonLivePhotoVideoCodecType;
    // One Live Photo's content identifier: the copy carries the receiver's, as the host's copies do.
    copy->_charonContentIdentifier = _charonContentIdentifier;
    copy->_charonLivePhotoMovieMetadata = _charonLivePhotoMovieMetadata;
    copy->_charonPreviewPhotoFormat = _charonPreviewPhotoFormat;
    copy->_charonEmbeddedThumbnailPhotoFormat = _charonEmbeddedThumbnailPhotoFormat;
    copy->_charonRawEmbeddedThumbnailPhotoFormat = _charonRawEmbeddedThumbnailPhotoFormat;
    copy->_charonAutoContentAwareDistortionCorrectionEnabled = _charonAutoContentAwareDistortionCorrectionEnabled;
    return copy;
}

// A copy is the same request: the receiver's unique ID and every setting (the host).
- (id)copyWithZone:(NSZone *)zone
{
    return [self charon_copyWithZone:zone uniqueID:_charonUniqueID];
}

// "A new AVCapturePhotoSettings object with a new uniqueID", every setting of the one given (the header, the host).
+ (instancetype)photoSettingsFromPhotoSettings:(AVCapturePhotoSettings *)photoSettings
{
    return [photoSettings charon_copyWithZone:NULL uniqueID:[AVCapturePhotoSettings charon_nextUniqueID]];
}

- (int64_t)uniqueID
{
    return _charonUniqueID;
}

- (NSDictionary<NSString *, id> *)format
{
    return _charonFormat;
}

- (AVFileType)processedFileType
{
    return _charonProcessedFileType;
}

- (OSType)rawPhotoPixelFormatType
{
    return _charonRawPhotoPixelFormatType;
}

- (AVFileType)rawFileType
{
    return _charonRawFileType;
}

// Any mode is kept; the capture refuses one the output does not offer (the header's flash rule).
- (AVCaptureFlashMode)flashMode
{
    return _charonFlashMode;
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode
{
    _charonFlashMode = flashMode;
}

- (BOOL)isAutoRedEyeReductionEnabled
{
    return _charonAutoRedEyeReductionEnabled;
}

- (void)setAutoRedEyeReductionEnabled:(BOOL)autoRedEyeReductionEnabled
{
    _charonAutoRedEyeReductionEnabled = autoRedEyeReductionEnabled;
}

- (AVCapturePhotoQualityPrioritization)photoQualityPrioritization
{
    return _charonPhotoQualityPrioritization;
}

- (void)setPhotoQualityPrioritization:(AVCapturePhotoQualityPrioritization)photoQualityPrioritization
{
    if (photoQualityPrioritization < AVCapturePhotoQualityPrioritizationSpeed || photoQualityPrioritization > AVCapturePhotoQualityPrioritizationQuality)
        CharonRaise(@"*** -[AVCapturePhotoSettings setPhotoQualityPrioritization:] Unsupported photo quality prioritization - %ld", (long)photoQualityPrioritization);
    _charonPhotoQualityPrioritization = photoQualityPrioritization;
}

- (BOOL)isAutoStillImageStabilizationEnabled
{
    return _charonAutoStillImageStabilizationEnabled;
}

- (void)setAutoStillImageStabilizationEnabled:(BOOL)autoStillImageStabilizationEnabled
{
    _charonAutoStillImageStabilizationEnabled = autoStillImageStabilizationEnabled;
}

- (BOOL)isAutoVirtualDeviceFusionEnabled
{
    return _charonAutoVirtualDeviceFusionEnabled;
}

- (void)setAutoVirtualDeviceFusionEnabled:(BOOL)autoVirtualDeviceFusionEnabled
{
    _charonAutoVirtualDeviceFusionEnabled = autoVirtualDeviceFusionEnabled;
}

- (BOOL)isAutoDualCameraFusionEnabled
{
    return _charonAutoVirtualDeviceFusionEnabled;
}

- (void)setAutoDualCameraFusionEnabled:(BOOL)autoDualCameraFusionEnabled
{
    _charonAutoVirtualDeviceFusionEnabled = autoDualCameraFusionEnabled;
}

- (NSArray<AVCaptureDevice *> *)virtualDeviceConstituentPhotoDeliveryEnabledDevices
{
    return _charonVirtualDeviceConstituentPhotoDeliveryEnabledDevices;
}

- (void)setVirtualDeviceConstituentPhotoDeliveryEnabledDevices:(NSArray<AVCaptureDevice *> *)devices
{
    _charonVirtualDeviceConstituentPhotoDeliveryEnabledDevices = [devices copy] ?: @[];
}

- (BOOL)isDualCameraDualPhotoDeliveryEnabled
{
    return _charonDualCameraDualPhotoDeliveryEnabled;
}

- (void)setDualCameraDualPhotoDeliveryEnabled:(BOOL)dualCameraDualPhotoDeliveryEnabled
{
    _charonDualCameraDualPhotoDeliveryEnabled = dualCameraDualPhotoDeliveryEnabled;
}

- (BOOL)isHighResolutionPhotoEnabled
{
    return _charonHighResolutionPhotoEnabled;
}

// Setting it, YES or NO, takes back any maxPhotoDimensions given, which it replaces (the host).
- (void)setHighResolutionPhotoEnabled:(BOOL)highResolutionPhotoEnabled
{
    _charonHighResolutionPhotoEnabled = highResolutionPhotoEnabled;
    _charonMaxPhotoDimensions = (CMVideoDimensions){0, 0};
}

- (CMVideoDimensions)maxPhotoDimensions
{
    return _charonMaxPhotoDimensions;
}

- (void)setMaxPhotoDimensions:(CMVideoDimensions)maxPhotoDimensions
{
    _charonMaxPhotoDimensions = maxPhotoDimensions;
}

- (BOOL)isDepthDataDeliveryEnabled
{
    return _charonDepthDataDeliveryEnabled;
}

- (void)setDepthDataDeliveryEnabled:(BOOL)depthDataDeliveryEnabled
{
    _charonDepthDataDeliveryEnabled = depthDataDeliveryEnabled;
}

- (BOOL)embedsDepthDataInPhoto
{
    return _charonEmbedsDepthDataInPhoto;
}

- (void)setEmbedsDepthDataInPhoto:(BOOL)embedsDepthDataInPhoto
{
    _charonEmbedsDepthDataInPhoto = embedsDepthDataInPhoto;
}

- (BOOL)isDepthDataFiltered
{
    return _charonDepthDataFiltered;
}

- (void)setDepthDataFiltered:(BOOL)depthDataFiltered
{
    _charonDepthDataFiltered = depthDataFiltered;
}

- (BOOL)isCameraCalibrationDataDeliveryEnabled
{
    return _charonCameraCalibrationDataDeliveryEnabled;
}

- (void)setCameraCalibrationDataDeliveryEnabled:(BOOL)cameraCalibrationDataDeliveryEnabled
{
    _charonCameraCalibrationDataDeliveryEnabled = cameraCalibrationDataDeliveryEnabled;
}

- (BOOL)isPortraitEffectsMatteDeliveryEnabled
{
    return _charonPortraitEffectsMatteDeliveryEnabled;
}

- (void)setPortraitEffectsMatteDeliveryEnabled:(BOOL)portraitEffectsMatteDeliveryEnabled
{
    _charonPortraitEffectsMatteDeliveryEnabled = portraitEffectsMatteDeliveryEnabled;
}

- (BOOL)embedsPortraitEffectsMatteInPhoto
{
    return _charonEmbedsPortraitEffectsMatteInPhoto;
}

- (void)setEmbedsPortraitEffectsMatteInPhoto:(BOOL)embedsPortraitEffectsMatteInPhoto
{
    _charonEmbedsPortraitEffectsMatteInPhoto = embedsPortraitEffectsMatteInPhoto;
}

- (NSArray<AVSemanticSegmentationMatteType> *)enabledSemanticSegmentationMatteTypes
{
    return _charonEnabledSemanticSegmentationMatteTypes;
}

- (void)setEnabledSemanticSegmentationMatteTypes:(NSArray<AVSemanticSegmentationMatteType> *)types
{
    _charonEnabledSemanticSegmentationMatteTypes = [types copy] ?: @[];
}

- (BOOL)embedsSemanticSegmentationMattesInPhoto
{
    return _charonEmbedsSemanticSegmentationMattesInPhoto;
}

- (void)setEmbedsSemanticSegmentationMattesInPhoto:(BOOL)embedsSemanticSegmentationMattesInPhoto
{
    _charonEmbedsSemanticSegmentationMattesInPhoto = embedsSemanticSegmentationMattesInPhoto;
}

- (NSDictionary<NSString *, id> *)metadata
{
    return _charonMetadata;
}

// Only the top-level keys are checked, and a key outside <ImageIO/CGImageProperties.h> is refused with the host's text.
- (void)setMetadata:(NSDictionary<NSString *, id> *)metadata
{
    NSMutableSet *invalid = [NSMutableSet setWithArray:metadata.allKeys ?: @[]];
    [invalid minusSet:CharonMetadataKeys()];
    if (invalid.count)
        CharonRaise(@"*** -[AVCapturePhotoSettings setMetadata:] Invalid top-level keys passed in metadata: %@", invalid);
    _charonMetadata = [metadata copy] ?: @{};
}

- (NSURL *)livePhotoMovieFileURL
{
    return _charonLivePhotoMovieFileURL;
}

- (void)setLivePhotoMovieFileURL:(NSURL *)livePhotoMovieFileURL
{
    _charonLivePhotoMovieFileURL = [livePhotoMovieFileURL copy];
}

- (AVVideoCodecType)livePhotoVideoCodecType
{
    return _charonLivePhotoVideoCodecType;
}

- (void)setLivePhotoVideoCodecType:(AVVideoCodecType)livePhotoVideoCodecType
{
    _charonLivePhotoVideoCodecType = [livePhotoVideoCodecType copy];
}

- (NSArray<AVMetadataItem *> *)livePhotoMovieMetadata
{
    return _charonLivePhotoMovieMetadata;
}

// The items given, then the settings' own content identifier; nil gives the identifier alone (null_resettable). An item
// of the application's own for the content identifier is refused with the host's text.
- (void)setLivePhotoMovieMetadata:(NSArray<AVMetadataItem *> *)livePhotoMovieMetadata
{
    for (AVMetadataItem *item in livePhotoMovieMetadata)
        if (CharonIsContentIdentifierItem(item))
            CharonRaise(@"*** -[AVCapturePhotoSettings setLivePhotoMovieMetadata:] AVMetadataKeySpaceQuickTimeMetadata/AVMetadataQuickTimeMetadataKeyContentIdentifier must not be specified");
    NSMutableArray *items = [NSMutableArray arrayWithArray:livePhotoMovieMetadata ?: @[]];
    [items addObject:CharonContentIdentifierItem(_charonContentIdentifier)];
    _charonLivePhotoMovieMetadata = [items copy];
}

// The preview is drawn by the port from the captured still (facts): in the three formats the host offers, in its order,
// 32BGRA as CoreGraphics draws it and 420v and 420f converted from that by BT.601.
- (NSArray<NSNumber *> *)availablePreviewPhotoPixelFormatTypes
{
    return @[@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), @(kCVPixelFormatType_32BGRA)];
}

- (NSDictionary<NSString *, id> *)previewPhotoFormat
{
    return _charonPreviewPhotoFormat;
}

// The pixel format is required and must be one available; width and height are checked at capture (the host).
- (void)setPreviewPhotoFormat:(NSDictionary<NSString *, id> *)previewPhotoFormat
{
    if (previewPhotoFormat) {
        NSNumber *pixels = CharonPixelFormatOf(previewPhotoFormat);
        if (!pixels)
            CharonRaise(@"*** -[AVCapturePhotoSettings setPreviewPhotoFormat:] Either kCVPixelBufferPixelFormatTypeKey or AVVideoCodecKey must be specified");
        if (![self.availablePreviewPhotoPixelFormatTypes containsObject:pixels])
            CharonRaise(@"*** -[AVCapturePhotoSettings setPreviewPhotoFormat:] Unsupported pixel format type specified: %@. Supported pixel format types are %@",
                        pixels, self.availablePreviewPhotoPixelFormatTypes);
    }
    _charonPreviewPhotoFormat = [previewPhotoFormat copy];
}

// The thumbnail the capture can embed: a JPEG, written by the photo output into the Exif of a JPEG photo (IFD1, the
// Exif standard's thumbnail), so it is offered for a JPEG format and for nothing else: the port delivers an uncompressed
// photo as a pixel buffer, with no file to hold a thumbnail, and makes no HEIC. The host offers JPEG for those too
// (facts, "The photo settings"): a thumbnail for an uncompressed, HEVC or RAW photo is not implemented (facts, "Open").
- (NSArray<AVVideoCodecType> *)availableEmbeddedThumbnailPhotoCodecTypes
{
    return [CharonCodecOf(_charonFormat) isEqualToString:AVVideoCodecTypeJPEG] ? @[AVVideoCodecTypeJPEG] : @[];
}

- (NSArray<AVVideoCodecType> *)availableRawEmbeddedThumbnailPhotoCodecTypes
{
    return @[];
}

static void CharonCheckThumbnailFormat(NSDictionary *format, NSArray *available, NSString *method)
{
    if (!format)
        return;
    if (CharonPixelFormatOf(format))
        CharonRaise(@"*** %@ kCVPixelBufferPixelFormatTypeKey is unsupported", method);
    NSString *codec = CharonCodecOf(format);
    if (!codec)
        CharonRaise(@"*** %@ Either kCVPixelBufferPixelFormatTypeKey or AVVideoCodecKey must be specified", method);
    if (![available containsObject:codec])
        CharonRaise(@"*** %@ Unsupported codec specified: %@. Supported codecs are %@", method, codec, available);
}

- (NSDictionary<NSString *, id> *)embeddedThumbnailPhotoFormat
{
    return _charonEmbeddedThumbnailPhotoFormat;
}

- (void)setEmbeddedThumbnailPhotoFormat:(NSDictionary<NSString *, id> *)embeddedThumbnailPhotoFormat
{
    CharonCheckThumbnailFormat(embeddedThumbnailPhotoFormat, self.availableEmbeddedThumbnailPhotoCodecTypes, @"-[AVCapturePhotoSettings setEmbeddedThumbnailPhotoFormat:]");
    _charonEmbeddedThumbnailPhotoFormat = [embeddedThumbnailPhotoFormat copy];
}

- (NSDictionary<NSString *, id> *)rawEmbeddedThumbnailPhotoFormat
{
    return _charonRawEmbeddedThumbnailPhotoFormat;
}

- (void)setRawEmbeddedThumbnailPhotoFormat:(NSDictionary<NSString *, id> *)rawEmbeddedThumbnailPhotoFormat
{
    CharonCheckThumbnailFormat(rawEmbeddedThumbnailPhotoFormat, self.availableRawEmbeddedThumbnailPhotoCodecTypes,
                               @"-[AVCapturePhotoSettings setRawEmbeddedThumbnailPhotoFormat:]");
    _charonRawEmbeddedThumbnailPhotoFormat = [rawEmbeddedThumbnailPhotoFormat copy];
}

- (BOOL)isAutoContentAwareDistortionCorrectionEnabled
{
    return _charonAutoContentAwareDistortionCorrectionEnabled;
}

- (void)setAutoContentAwareDistortionCorrectionEnabled:(BOOL)autoContentAwareDistortionCorrectionEnabled
{
    _charonAutoContentAwareDistortionCorrectionEnabled = autoContentAwareDistortionCorrectionEnabled;
}

@end
