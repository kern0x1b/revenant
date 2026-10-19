#import "CharonAVCapturePhoto.h"
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>

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
    copy->_charonContentIdentifier = _charonContentIdentifier;
    copy->_charonLivePhotoMovieMetadata = _charonLivePhotoMovieMetadata;
    copy->_charonPreviewPhotoFormat = _charonPreviewPhotoFormat;
    copy->_charonEmbeddedThumbnailPhotoFormat = _charonEmbeddedThumbnailPhotoFormat;
    copy->_charonRawEmbeddedThumbnailPhotoFormat = _charonRawEmbeddedThumbnailPhotoFormat;
    copy->_charonAutoContentAwareDistortionCorrectionEnabled = _charonAutoContentAwareDistortionCorrectionEnabled;
    return copy;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self charon_copyWithZone:zone uniqueID:_charonUniqueID];
}

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

- (void)setLivePhotoMovieMetadata:(NSArray<AVMetadataItem *> *)livePhotoMovieMetadata
{
    for (AVMetadataItem *item in livePhotoMovieMetadata)
        if (CharonIsContentIdentifierItem(item))
            CharonRaise(@"*** -[AVCapturePhotoSettings setLivePhotoMovieMetadata:] AVMetadataKeySpaceQuickTimeMetadata/AVMetadataQuickTimeMetadataKeyContentIdentifier must not be specified");
    NSMutableArray *items = [NSMutableArray arrayWithArray:livePhotoMovieMetadata ?: @[]];
    [items addObject:CharonContentIdentifierItem(_charonContentIdentifier)];
    _charonLivePhotoMovieMetadata = [items copy];
}

- (NSArray<NSNumber *> *)availablePreviewPhotoPixelFormatTypes
{
    return @[@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), @(kCVPixelFormatType_32BGRA)];
}

- (NSDictionary<NSString *, id> *)previewPhotoFormat
{
    return _charonPreviewPhotoFormat;
}

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
