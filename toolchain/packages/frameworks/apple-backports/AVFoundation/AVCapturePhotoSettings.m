#import "RevenantAVCapturePhoto.h"
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>

BOOL RevenantIsBayerRAWPixelFormat(OSType format)
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

BOOL RevenantIsAppleProRAWPixelFormat(OSType format)
{
    return format == kCVPixelFormatType_64RGBALE;
}

static void RevenantRaise(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void RevenantRaise(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
}

static NSNumber *RevenantPixelFormatOf(NSDictionary *format)
{
    id value = format[(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey];
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

static NSString *RevenantCodecOf(NSDictionary *format)
{
    id value = format[AVVideoCodecKey];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static void RevenantCheckProcessedFormat(NSDictionary *format, NSString *method)
{
    if (!format)
        return;
    if (format.count == 0)
        RevenantRaise(@"*** %@ source passthru (empty dictionary) is not supported", method);
    BOOL pixels = RevenantPixelFormatOf(format) != nil, codec = RevenantCodecOf(format) != nil;
    if (!pixels && !codec)
        RevenantRaise(@"*** %@ Either kCVPixelBufferPixelFormatTypeKey or AVVideoCodecKey must be specified", method);
    if (pixels && codec)
        RevenantRaise(@"*** %@ kCVPixelBufferPixelFormatTypeKey and AVVideoCodecKey may not both be specified", method);
}

static NSString *RevenantDefaultProcessedFileType(NSDictionary *format)
{
    NSString *codec = RevenantCodecOf(format);
    if (!codec)
        return RevenantPixelFormatOf(format) ? AVFileTypeTIFF : nil;
    if ([codec isEqualToString:AVVideoCodecTypeJPEG])
        return AVFileTypeJPEG;
    if ([codec isEqualToString:AVVideoCodecTypeHEVC])
        return AVFileTypeHEIC;
    return nil;
}

static NSSet *RevenantMetadataKeys(void)
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

static AVMetadataItem *RevenantContentIdentifierItem(NSString *identifier)
{
    AVMutableMetadataItem *item = [AVMutableMetadataItem metadataItem];
    item.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    item.key = AVMetadataQuickTimeMetadataKeyContentIdentifier;
    item.value = identifier;
    return item;
}

static BOOL RevenantIsContentIdentifierItem(AVMetadataItem *item)
{
    return [item.keySpace isEqualToString:AVMetadataKeySpaceQuickTimeMetadata] && [(id)item.key isEqual:AVMetadataQuickTimeMetadataKeyContentIdentifier];
}

@implementation AVCapturePhotoSettings
{
    int64_t _revenantUniqueID;
    NSDictionary *_revenantFormat;
    NSString *_revenantProcessedFileType;
    OSType _revenantRawPhotoPixelFormatType;
    NSString *_revenantRawFileType;
    AVCaptureFlashMode _revenantFlashMode;
    BOOL _revenantAutoRedEyeReductionEnabled;
    AVCapturePhotoQualityPrioritization _revenantPhotoQualityPrioritization;
    BOOL _revenantAutoStillImageStabilizationEnabled;
    BOOL _revenantAutoVirtualDeviceFusionEnabled;
    NSArray *_revenantVirtualDeviceConstituentPhotoDeliveryEnabledDevices;
    BOOL _revenantDualCameraDualPhotoDeliveryEnabled;
    BOOL _revenantHighResolutionPhotoEnabled;
    CMVideoDimensions _revenantMaxPhotoDimensions;
    BOOL _revenantDepthDataDeliveryEnabled;
    BOOL _revenantEmbedsDepthDataInPhoto;
    BOOL _revenantDepthDataFiltered;
    BOOL _revenantCameraCalibrationDataDeliveryEnabled;
    BOOL _revenantPortraitEffectsMatteDeliveryEnabled;
    BOOL _revenantEmbedsPortraitEffectsMatteInPhoto;
    NSArray *_revenantEnabledSemanticSegmentationMatteTypes;
    BOOL _revenantEmbedsSemanticSegmentationMattesInPhoto;
    NSDictionary *_revenantMetadata;
    NSURL *_revenantLivePhotoMovieFileURL;
    NSString *_revenantLivePhotoVideoCodecType;
    NSString *_revenantContentIdentifier;
    NSArray *_revenantLivePhotoMovieMetadata;
    NSDictionary *_revenantPreviewPhotoFormat;
    NSDictionary *_revenantEmbeddedThumbnailPhotoFormat;
    NSDictionary *_revenantRawEmbeddedThumbnailPhotoFormat;
    BOOL _revenantAutoContentAwareDistortionCorrectionEnabled;
}

+ (int64_t)revenant_nextUniqueID
{
    static int64_t counter;
    @synchronized ([AVCapturePhotoSettings class]) {
        return ++counter;
    }
}

- (instancetype)init
{
    return [self initRevenantWithUniqueID:[AVCapturePhotoSettings revenant_nextUniqueID]];
}

- (instancetype)initRevenantWithUniqueID:(int64_t)uniqueID
{
    if ((self = [super init])) {
        _revenantUniqueID = uniqueID;
        _revenantFormat = @{AVVideoCodecKey: AVVideoCodecTypeJPEG};
        _revenantProcessedFileType = AVFileTypeJPEG;
        _revenantFlashMode = AVCaptureFlashModeOff;
        _revenantPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationBalanced;
        _revenantAutoStillImageStabilizationEnabled = YES;
        _revenantAutoVirtualDeviceFusionEnabled = YES;
        _revenantVirtualDeviceConstituentPhotoDeliveryEnabledDevices = @[];
        _revenantEmbedsDepthDataInPhoto = YES;
        _revenantDepthDataFiltered = YES;
        _revenantEmbedsPortraitEffectsMatteInPhoto = YES;
        _revenantEnabledSemanticSegmentationMatteTypes = @[];
        _revenantEmbedsSemanticSegmentationMattesInPhoto = YES;
        _revenantMetadata = @{};
        _revenantLivePhotoVideoCodecType = AVVideoCodecTypeH264;
        _revenantContentIdentifier = [NSUUID UUID].UUIDString;
        _revenantLivePhotoMovieMetadata = @[RevenantContentIdentifierItem(_revenantContentIdentifier)];
    }
    return self;
}

+ (instancetype)revenant_settingsWithRaw:(OSType)raw rawFileType:(NSString *)rawFileType format:(NSDictionary *)format
                     processedFileType:(NSString *)processedFileType method:(NSString *)method
{
    if (raw && !RevenantIsBayerRAWPixelFormat(raw) && !RevenantIsAppleProRAWPixelFormat(raw))
        RevenantRaise(@"*** %@ Unrecognized raw pixel format type", method);
    RevenantCheckProcessedFormat(format, method);
    AVCapturePhotoSettings *settings = [[self alloc] init];
    if (format || !raw) {
        settings->_revenantFormat = format ? [format copy] : @{AVVideoCodecKey: AVVideoCodecTypeJPEG};
        settings->_revenantProcessedFileType = processedFileType ?: RevenantDefaultProcessedFileType(settings->_revenantFormat);
    } else {
        settings->_revenantFormat = nil;
        settings->_revenantProcessedFileType = nil;
    }
    if (raw) {
        settings->_revenantRawPhotoPixelFormatType = raw;
        settings->_revenantRawFileType = rawFileType ?: AVFileTypeDNG;
        if (RevenantIsBayerRAWPixelFormat(raw)) {
            settings->_revenantPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationSpeed;
            settings->_revenantAutoStillImageStabilizationEnabled = NO;
            settings->_revenantAutoVirtualDeviceFusionEnabled = NO;
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
    return [self revenant_settingsWithRaw:0 rawFileType:nil format:format processedFileType:nil method:@"+[AVCapturePhotoSettings photoSettingsWithFormat:]"];
}

+ (instancetype)photoSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType
{
    return [self revenant_settingsWithRaw:rawPixelFormatType rawFileType:nil format:nil processedFileType:nil
                                 method:@"+[AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:]"];
}

+ (instancetype)photoSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType processedFormat:(NSDictionary<NSString *, id> *)processedFormat
{
    return [self revenant_settingsWithRaw:rawPixelFormatType rawFileType:nil format:processedFormat processedFileType:nil
                                 method:@"+[AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:processedFormat:]"];
}

+ (instancetype)photoSettingsWithRawPixelFormatType:(OSType)rawPixelFormatType rawFileType:(AVFileType)rawFileType
                                    processedFormat:(NSDictionary<NSString *, id> *)processedFormat processedFileType:(AVFileType)processedFileType
{
    return [self revenant_settingsWithRaw:rawPixelFormatType rawFileType:rawFileType format:processedFormat processedFileType:processedFileType
                                 method:@"+[AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:rawFileType:processedFormat:processedFileType:]"];
}

- (instancetype)revenant_copyWithZone:(NSZone *)zone uniqueID:(int64_t)uniqueID
{
    AVCapturePhotoSettings *copy = [[[self class] allocWithZone:zone] initRevenantWithUniqueID:uniqueID];
    copy->_revenantFormat = _revenantFormat;
    copy->_revenantProcessedFileType = _revenantProcessedFileType;
    copy->_revenantRawPhotoPixelFormatType = _revenantRawPhotoPixelFormatType;
    copy->_revenantRawFileType = _revenantRawFileType;
    copy->_revenantFlashMode = _revenantFlashMode;
    copy->_revenantAutoRedEyeReductionEnabled = _revenantAutoRedEyeReductionEnabled;
    copy->_revenantPhotoQualityPrioritization = _revenantPhotoQualityPrioritization;
    copy->_revenantAutoStillImageStabilizationEnabled = _revenantAutoStillImageStabilizationEnabled;
    copy->_revenantAutoVirtualDeviceFusionEnabled = _revenantAutoVirtualDeviceFusionEnabled;
    copy->_revenantVirtualDeviceConstituentPhotoDeliveryEnabledDevices = _revenantVirtualDeviceConstituentPhotoDeliveryEnabledDevices;
    copy->_revenantDualCameraDualPhotoDeliveryEnabled = _revenantDualCameraDualPhotoDeliveryEnabled;
    copy->_revenantHighResolutionPhotoEnabled = _revenantHighResolutionPhotoEnabled;
    copy->_revenantMaxPhotoDimensions = _revenantMaxPhotoDimensions;
    copy->_revenantDepthDataDeliveryEnabled = _revenantDepthDataDeliveryEnabled;
    copy->_revenantEmbedsDepthDataInPhoto = _revenantEmbedsDepthDataInPhoto;
    copy->_revenantDepthDataFiltered = _revenantDepthDataFiltered;
    copy->_revenantCameraCalibrationDataDeliveryEnabled = _revenantCameraCalibrationDataDeliveryEnabled;
    copy->_revenantPortraitEffectsMatteDeliveryEnabled = _revenantPortraitEffectsMatteDeliveryEnabled;
    copy->_revenantEmbedsPortraitEffectsMatteInPhoto = _revenantEmbedsPortraitEffectsMatteInPhoto;
    copy->_revenantEnabledSemanticSegmentationMatteTypes = _revenantEnabledSemanticSegmentationMatteTypes;
    copy->_revenantEmbedsSemanticSegmentationMattesInPhoto = _revenantEmbedsSemanticSegmentationMattesInPhoto;
    copy->_revenantMetadata = _revenantMetadata;
    copy->_revenantLivePhotoMovieFileURL = _revenantLivePhotoMovieFileURL;
    copy->_revenantLivePhotoVideoCodecType = _revenantLivePhotoVideoCodecType;
    copy->_revenantContentIdentifier = _revenantContentIdentifier;
    copy->_revenantLivePhotoMovieMetadata = _revenantLivePhotoMovieMetadata;
    copy->_revenantPreviewPhotoFormat = _revenantPreviewPhotoFormat;
    copy->_revenantEmbeddedThumbnailPhotoFormat = _revenantEmbeddedThumbnailPhotoFormat;
    copy->_revenantRawEmbeddedThumbnailPhotoFormat = _revenantRawEmbeddedThumbnailPhotoFormat;
    copy->_revenantAutoContentAwareDistortionCorrectionEnabled = _revenantAutoContentAwareDistortionCorrectionEnabled;
    return copy;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self revenant_copyWithZone:zone uniqueID:_revenantUniqueID];
}

+ (instancetype)photoSettingsFromPhotoSettings:(AVCapturePhotoSettings *)photoSettings
{
    return [photoSettings revenant_copyWithZone:NULL uniqueID:[AVCapturePhotoSettings revenant_nextUniqueID]];
}

- (int64_t)uniqueID
{
    return _revenantUniqueID;
}

- (NSDictionary<NSString *, id> *)format
{
    return _revenantFormat;
}

- (AVFileType)processedFileType
{
    return _revenantProcessedFileType;
}

- (OSType)rawPhotoPixelFormatType
{
    return _revenantRawPhotoPixelFormatType;
}

- (AVFileType)rawFileType
{
    return _revenantRawFileType;
}

- (AVCaptureFlashMode)flashMode
{
    return _revenantFlashMode;
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode
{
    _revenantFlashMode = flashMode;
}

- (BOOL)isAutoRedEyeReductionEnabled
{
    return _revenantAutoRedEyeReductionEnabled;
}

- (void)setAutoRedEyeReductionEnabled:(BOOL)autoRedEyeReductionEnabled
{
    _revenantAutoRedEyeReductionEnabled = autoRedEyeReductionEnabled;
}

- (AVCapturePhotoQualityPrioritization)photoQualityPrioritization
{
    return _revenantPhotoQualityPrioritization;
}

- (void)setPhotoQualityPrioritization:(AVCapturePhotoQualityPrioritization)photoQualityPrioritization
{
    if (photoQualityPrioritization < AVCapturePhotoQualityPrioritizationSpeed || photoQualityPrioritization > AVCapturePhotoQualityPrioritizationQuality)
        RevenantRaise(@"*** -[AVCapturePhotoSettings setPhotoQualityPrioritization:] Unsupported photo quality prioritization - %ld", (long)photoQualityPrioritization);
    _revenantPhotoQualityPrioritization = photoQualityPrioritization;
}

- (BOOL)isAutoStillImageStabilizationEnabled
{
    return _revenantAutoStillImageStabilizationEnabled;
}

- (void)setAutoStillImageStabilizationEnabled:(BOOL)autoStillImageStabilizationEnabled
{
    _revenantAutoStillImageStabilizationEnabled = autoStillImageStabilizationEnabled;
}

- (BOOL)isAutoVirtualDeviceFusionEnabled
{
    return _revenantAutoVirtualDeviceFusionEnabled;
}

- (void)setAutoVirtualDeviceFusionEnabled:(BOOL)autoVirtualDeviceFusionEnabled
{
    _revenantAutoVirtualDeviceFusionEnabled = autoVirtualDeviceFusionEnabled;
}

- (BOOL)isAutoDualCameraFusionEnabled
{
    return _revenantAutoVirtualDeviceFusionEnabled;
}

- (void)setAutoDualCameraFusionEnabled:(BOOL)autoDualCameraFusionEnabled
{
    _revenantAutoVirtualDeviceFusionEnabled = autoDualCameraFusionEnabled;
}

- (NSArray<AVCaptureDevice *> *)virtualDeviceConstituentPhotoDeliveryEnabledDevices
{
    return _revenantVirtualDeviceConstituentPhotoDeliveryEnabledDevices;
}

- (void)setVirtualDeviceConstituentPhotoDeliveryEnabledDevices:(NSArray<AVCaptureDevice *> *)devices
{
    _revenantVirtualDeviceConstituentPhotoDeliveryEnabledDevices = [devices copy] ?: @[];
}

- (BOOL)isDualCameraDualPhotoDeliveryEnabled
{
    return _revenantDualCameraDualPhotoDeliveryEnabled;
}

- (void)setDualCameraDualPhotoDeliveryEnabled:(BOOL)dualCameraDualPhotoDeliveryEnabled
{
    _revenantDualCameraDualPhotoDeliveryEnabled = dualCameraDualPhotoDeliveryEnabled;
}

- (BOOL)isHighResolutionPhotoEnabled
{
    return _revenantHighResolutionPhotoEnabled;
}

- (void)setHighResolutionPhotoEnabled:(BOOL)highResolutionPhotoEnabled
{
    _revenantHighResolutionPhotoEnabled = highResolutionPhotoEnabled;
    _revenantMaxPhotoDimensions = (CMVideoDimensions){0, 0};
}

- (CMVideoDimensions)maxPhotoDimensions
{
    return _revenantMaxPhotoDimensions;
}

- (void)setMaxPhotoDimensions:(CMVideoDimensions)maxPhotoDimensions
{
    _revenantMaxPhotoDimensions = maxPhotoDimensions;
}

- (BOOL)isDepthDataDeliveryEnabled
{
    return _revenantDepthDataDeliveryEnabled;
}

- (void)setDepthDataDeliveryEnabled:(BOOL)depthDataDeliveryEnabled
{
    _revenantDepthDataDeliveryEnabled = depthDataDeliveryEnabled;
}

- (BOOL)embedsDepthDataInPhoto
{
    return _revenantEmbedsDepthDataInPhoto;
}

- (void)setEmbedsDepthDataInPhoto:(BOOL)embedsDepthDataInPhoto
{
    _revenantEmbedsDepthDataInPhoto = embedsDepthDataInPhoto;
}

- (BOOL)isDepthDataFiltered
{
    return _revenantDepthDataFiltered;
}

- (void)setDepthDataFiltered:(BOOL)depthDataFiltered
{
    _revenantDepthDataFiltered = depthDataFiltered;
}

- (BOOL)isCameraCalibrationDataDeliveryEnabled
{
    return _revenantCameraCalibrationDataDeliveryEnabled;
}

- (void)setCameraCalibrationDataDeliveryEnabled:(BOOL)cameraCalibrationDataDeliveryEnabled
{
    _revenantCameraCalibrationDataDeliveryEnabled = cameraCalibrationDataDeliveryEnabled;
}

- (BOOL)isPortraitEffectsMatteDeliveryEnabled
{
    return _revenantPortraitEffectsMatteDeliveryEnabled;
}

- (void)setPortraitEffectsMatteDeliveryEnabled:(BOOL)portraitEffectsMatteDeliveryEnabled
{
    _revenantPortraitEffectsMatteDeliveryEnabled = portraitEffectsMatteDeliveryEnabled;
}

- (BOOL)embedsPortraitEffectsMatteInPhoto
{
    return _revenantEmbedsPortraitEffectsMatteInPhoto;
}

- (void)setEmbedsPortraitEffectsMatteInPhoto:(BOOL)embedsPortraitEffectsMatteInPhoto
{
    _revenantEmbedsPortraitEffectsMatteInPhoto = embedsPortraitEffectsMatteInPhoto;
}

- (NSArray<AVSemanticSegmentationMatteType> *)enabledSemanticSegmentationMatteTypes
{
    return _revenantEnabledSemanticSegmentationMatteTypes;
}

- (void)setEnabledSemanticSegmentationMatteTypes:(NSArray<AVSemanticSegmentationMatteType> *)types
{
    _revenantEnabledSemanticSegmentationMatteTypes = [types copy] ?: @[];
}

- (BOOL)embedsSemanticSegmentationMattesInPhoto
{
    return _revenantEmbedsSemanticSegmentationMattesInPhoto;
}

- (void)setEmbedsSemanticSegmentationMattesInPhoto:(BOOL)embedsSemanticSegmentationMattesInPhoto
{
    _revenantEmbedsSemanticSegmentationMattesInPhoto = embedsSemanticSegmentationMattesInPhoto;
}

- (NSDictionary<NSString *, id> *)metadata
{
    return _revenantMetadata;
}

- (void)setMetadata:(NSDictionary<NSString *, id> *)metadata
{
    NSMutableSet *invalid = [NSMutableSet setWithArray:metadata.allKeys ?: @[]];
    [invalid minusSet:RevenantMetadataKeys()];
    if (invalid.count)
        RevenantRaise(@"*** -[AVCapturePhotoSettings setMetadata:] Invalid top-level keys passed in metadata: %@", invalid);
    _revenantMetadata = [metadata copy] ?: @{};
}

- (NSURL *)livePhotoMovieFileURL
{
    return _revenantLivePhotoMovieFileURL;
}

- (void)setLivePhotoMovieFileURL:(NSURL *)livePhotoMovieFileURL
{
    _revenantLivePhotoMovieFileURL = [livePhotoMovieFileURL copy];
}

- (AVVideoCodecType)livePhotoVideoCodecType
{
    return _revenantLivePhotoVideoCodecType;
}

- (void)setLivePhotoVideoCodecType:(AVVideoCodecType)livePhotoVideoCodecType
{
    _revenantLivePhotoVideoCodecType = [livePhotoVideoCodecType copy];
}

- (NSArray<AVMetadataItem *> *)livePhotoMovieMetadata
{
    return _revenantLivePhotoMovieMetadata;
}

- (void)setLivePhotoMovieMetadata:(NSArray<AVMetadataItem *> *)livePhotoMovieMetadata
{
    for (AVMetadataItem *item in livePhotoMovieMetadata)
        if (RevenantIsContentIdentifierItem(item))
            RevenantRaise(@"*** -[AVCapturePhotoSettings setLivePhotoMovieMetadata:] AVMetadataKeySpaceQuickTimeMetadata/AVMetadataQuickTimeMetadataKeyContentIdentifier must not be specified");
    NSMutableArray *items = [NSMutableArray arrayWithArray:livePhotoMovieMetadata ?: @[]];
    [items addObject:RevenantContentIdentifierItem(_revenantContentIdentifier)];
    _revenantLivePhotoMovieMetadata = [items copy];
}

- (NSArray<NSNumber *> *)availablePreviewPhotoPixelFormatTypes
{
    return @[@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), @(kCVPixelFormatType_32BGRA)];
}

- (NSDictionary<NSString *, id> *)previewPhotoFormat
{
    return _revenantPreviewPhotoFormat;
}

- (void)setPreviewPhotoFormat:(NSDictionary<NSString *, id> *)previewPhotoFormat
{
    if (previewPhotoFormat) {
        NSNumber *pixels = RevenantPixelFormatOf(previewPhotoFormat);
        if (!pixels)
            RevenantRaise(@"*** -[AVCapturePhotoSettings setPreviewPhotoFormat:] Either kCVPixelBufferPixelFormatTypeKey or AVVideoCodecKey must be specified");
        if (![self.availablePreviewPhotoPixelFormatTypes containsObject:pixels])
            RevenantRaise(@"*** -[AVCapturePhotoSettings setPreviewPhotoFormat:] Unsupported pixel format type specified: %@. Supported pixel format types are %@",
                        pixels, self.availablePreviewPhotoPixelFormatTypes);
    }
    _revenantPreviewPhotoFormat = [previewPhotoFormat copy];
}

- (NSArray<AVVideoCodecType> *)availableEmbeddedThumbnailPhotoCodecTypes
{
    return [RevenantCodecOf(_revenantFormat) isEqualToString:AVVideoCodecTypeJPEG] ? @[AVVideoCodecTypeJPEG] : @[];
}

- (NSArray<AVVideoCodecType> *)availableRawEmbeddedThumbnailPhotoCodecTypes
{
    return @[];
}

static void RevenantCheckThumbnailFormat(NSDictionary *format, NSArray *available, NSString *method)
{
    if (!format)
        return;
    if (RevenantPixelFormatOf(format))
        RevenantRaise(@"*** %@ kCVPixelBufferPixelFormatTypeKey is unsupported", method);
    NSString *codec = RevenantCodecOf(format);
    if (!codec)
        RevenantRaise(@"*** %@ Either kCVPixelBufferPixelFormatTypeKey or AVVideoCodecKey must be specified", method);
    if (![available containsObject:codec])
        RevenantRaise(@"*** %@ Unsupported codec specified: %@. Supported codecs are %@", method, codec, available);
}

- (NSDictionary<NSString *, id> *)embeddedThumbnailPhotoFormat
{
    return _revenantEmbeddedThumbnailPhotoFormat;
}

- (void)setEmbeddedThumbnailPhotoFormat:(NSDictionary<NSString *, id> *)embeddedThumbnailPhotoFormat
{
    RevenantCheckThumbnailFormat(embeddedThumbnailPhotoFormat, self.availableEmbeddedThumbnailPhotoCodecTypes, @"-[AVCapturePhotoSettings setEmbeddedThumbnailPhotoFormat:]");
    _revenantEmbeddedThumbnailPhotoFormat = [embeddedThumbnailPhotoFormat copy];
}

- (NSDictionary<NSString *, id> *)rawEmbeddedThumbnailPhotoFormat
{
    return _revenantRawEmbeddedThumbnailPhotoFormat;
}

- (void)setRawEmbeddedThumbnailPhotoFormat:(NSDictionary<NSString *, id> *)rawEmbeddedThumbnailPhotoFormat
{
    RevenantCheckThumbnailFormat(rawEmbeddedThumbnailPhotoFormat, self.availableRawEmbeddedThumbnailPhotoCodecTypes,
                               @"-[AVCapturePhotoSettings setRawEmbeddedThumbnailPhotoFormat:]");
    _revenantRawEmbeddedThumbnailPhotoFormat = [rawEmbeddedThumbnailPhotoFormat copy];
}

- (BOOL)isAutoContentAwareDistortionCorrectionEnabled
{
    return _revenantAutoContentAwareDistortionCorrectionEnabled;
}

- (void)setAutoContentAwareDistortionCorrectionEnabled:(BOOL)autoContentAwareDistortionCorrectionEnabled
{
    _revenantAutoContentAwareDistortionCorrectionEnabled = autoContentAwareDistortionCorrectionEnabled;
}

@end
