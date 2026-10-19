#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#include <string.h>
#import "../../device/jpeg-exif.h"

// AVCapturePhotoSettings and AVCapturePhotoOutput of the port (built under the names CharonHostAVCapturePhotoSettings and
// CharonHostAVCapturePhotoOutput) against the host's own classes, with no camera. Every member the SDK the package
// builds with declares (read from its header by run.sh: "<class> -|+ <selector>" per line, the file given as argument
// 1) is answered by the port with the host's type encoding, and the port holds no ivar the compiler synthesized for a
// header property. Then the same requests are made of both, and each answer, value or exception, must be the host's.
// Where the port answers otherwise on purpose (the facts name each), the check is that both still answer as measured, so
// the check fails if the host ever stops diverging.

static int checks, failures;

static void check(BOOL passed, NSString *what)
{
    checks++;
    if (!passed)
        failures++;
    printf("%s %s\n", passed ? "ok  " : "FAIL", what.UTF8String);
}

static Class hostSettings, portSettings, hostOutput, portOutput;
static NSMutableDictionary<NSString *, NSMutableArray *> *declared;

// What an expression answers: its value's description, or the exception it raises.
static NSString *answer(id (^block)(void))
{
    @try {
        id value = block();
        return value ? [value description] : @"nil";
    } @catch (NSException *e) {
        return [NSString stringWithFormat:@"RAISES %@: %@", e.name, e.reason];
    }
}

// The same request of the host's class and the port's: the answers must be equal.
static void same(NSString *what, id (^block)(Class settings, Class output))
{
    NSString *host = answer(^{ return block(hostSettings, hostOutput); }), *port = answer(^{ return block(portSettings, portOutput); });
    BOOL equal = [host isEqualToString:port];
    check(equal, equal ? [NSString stringWithFormat:@"%@: %@", what, [host stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]
                       : [NSString stringWithFormat:@"%@\n     host: %@\n     port: %@", what, host, port]);
}

// A known divergence: the host answers `hostExpected` and the port `portExpected`.
static void differs(NSString *what, NSString *hostExpected, NSString *portExpected, id (^block)(Class settings, Class output))
{
    NSString *host = answer(^{ return block(hostSettings, hostOutput); }), *port = answer(^{ return block(portSettings, portOutput); });
    check([host isEqualToString:hostExpected] && [port isEqualToString:portExpected],
          [NSString stringWithFormat:@"%@ (named divergence)\n     host: %@ (expected %@)\n     port: %@ (expected %@)", what, host, hostExpected, port, portExpected]);
}

// Every getter the header declares on the settings (an instance selector with no argument), except those whose answer is
// the object's identity: its unique ID, and the content identifier inside livePhotoMovieMetadata.
static NSArray<NSString *> *getters(NSString *className, NSSet *skip)
{
    NSMutableArray *list = [NSMutableArray array];
    for (NSString *line in declared[className])
        if ([line hasPrefix:@"- "] && ![line containsString:@":"] && ![skip containsObject:[line substringFromIndex:2]])
            [list addObject:[line substringFromIndex:2]];
    return list;
}

static NSString *dump(id object, NSArray<NSString *> *keys)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in keys)
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, answer(^{ return [object valueForKey:key]; })]];
    return [parts componentsJoinedByString:@" "];
}

static NSSet *settingsIdentity(void)
{
    return [NSSet setWithObjects:@"uniqueID", @"livePhotoMovieMetadata", nil];
}

// The three settings getters the port answers otherwise than the host in some settings (facts, "The photo settings"):
// stabilization is YES by the header's default where the Mac answers NO, and the thumbnail codecs of an uncompressed, an
// HEVC or a RAW photo are not offered, which is work still to do. They are left out of `settingsDump` and compared apart
// by `settingsSame`, for every settings object every check builds: equal, or as the row of `divergences()` for that check
// states, the host's answer and the port's.
static NSArray<NSString *> *divergentGetters(void)
{
    return @[@"isAutoStillImageStabilizationEnabled", @"availableEmbeddedThumbnailPhotoCodecTypes", @"availableRawEmbeddedThumbnailPhotoCodecTypes"];
}

static NSString *settingsDump(AVCapturePhotoSettings *settings)
{
    NSMutableSet *skip = [settingsIdentity() mutableCopy];
    [skip addObjectsFromArray:divergentGetters()];
    return dump(settings, getters(@"AVCapturePhotoSettings", skip));
}

// The three answers on one line, a codec list as `jpeg,hvc1` and an empty one as nothing.
static NSString *divergentDump(AVCapturePhotoSettings *settings)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in divergentGetters()) {
        NSString *text = answer(^{ return [settings valueForKey:key]; });
        text = [[text componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"() \n"]] componentsJoinedByString:@""];
        [parts addObject:[NSString stringWithFormat:@"%@=%@", [key hasPrefix:@"isAuto"] ? @"stabilization" : [key hasPrefix:@"availableRaw"] ? @"rawThumbnails" : @"thumbnails", text]];
    }
    return [parts componentsJoinedByString:@" "];
}

// Every getter of a dump and the three of `divergentDump`, of one side's own settings.
static NSString *fullDump(AVCapturePhotoSettings *settings)
{
    return [settingsDump(settings) stringByAppendingFormat:@" %@", divergentDump(settings)];
}

// The rows of divergences.tsv: a check's key, the host's answer of the three getters and the port's, tab separated.
static NSDictionary<NSString *, NSArray<NSString *> *> *divergenceRows;

static NSDictionary<NSString *, NSArray<NSString *> *> *divergences(void)
{
    return divergenceRows;
}

// Two settings the same but in the three getters above, which are either equal or as `key`'s row states. The settings come
// from `block`, built for the host and for the port.
static void settingsSame(NSString *what, NSString *key, id (^block)(Class settings, Class output))
{
    same(what, ^id(Class s, Class o) { return settingsDump(block(s, o)); });
    NSString *host = answer(^{ return divergentDump(block(hostSettings, hostOutput)); }), *port = answer(^{ return divergentDump(block(portSettings, portOutput)); });
    NSArray<NSString *> *row = divergences()[key];
    // A setter that raises builds no settings: what it raised is `same`'s to compare above.
    if ([host hasPrefix:@"RAISES"] && [host isEqualToString:port])
        check(YES, [NSString stringWithFormat:@"%@: raised on both sides, no settings to compare", what]);
    else if (row)
        check([host isEqualToString:row[0]] && [port isEqualToString:row[1]],
              [NSString stringWithFormat:@"%@: stabilization and thumbnail codecs, as its row of divergences.tsv states\n     host: %@ (expected %@)\n     port: %@ (expected %@)", what, host, row[0], port, row[1]]);
    else
        check([host isEqualToString:port], [host isEqualToString:port] ? [NSString stringWithFormat:@"%@: stabilization and thumbnail codecs %@", what, host]
                                                                        : [NSString stringWithFormat:@"%@: stabilization and thumbnail codecs\n     row: %@\t%@\t%@", what, key, host, port]);
}

static void members(NSString *className, Class system, Class ours)
{
    for (NSString *line in declared[className]) {
        BOOL instance = [line hasPrefix:@"- "];
        NSString *name = [line substringFromIndex:2];
        SEL selector = NSSelectorFromString(name);
        Method host = instance ? class_getInstanceMethod(system, selector) : class_getClassMethod(system, selector);
        Method port = instance ? class_getInstanceMethod(ours, selector) : class_getClassMethod(ours, selector);
        if (!host) {
            printf("note %s %s: the host's class does not answer it\n", className.UTF8String, line.UTF8String);
            check(port != NULL, [NSString stringWithFormat:@"%@ %@ is answered by the port", className, line]);
            continue;
        }
        const char *hostTypes = method_getTypeEncoding(host), *portTypes = port ? method_getTypeEncoding(port) : "";
        check(port != NULL && strcmp(hostTypes, portTypes) == 0,
              [NSString stringWithFormat:@"%@ %@ is answered by the port as by the host: %s / %s", className, line, hostTypes, portTypes]);
    }
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(ours, &count);
    for (unsigned int i = 0; i < count; i++) {
        NSString *ivar = @(ivar_getName(ivars[i]));
        if (![ivar hasPrefix:@"_"])
            continue;
        NSString *bare = [ivar substringFromIndex:1];
        NSString *is = [@"- is" stringByAppendingString:[[bare substringToIndex:1].uppercaseString stringByAppendingString:[bare substringFromIndex:1]]];
        BOOL synthesized = [declared[className] containsObject:[@"- " stringByAppendingString:bare]] || [declared[className] containsObject:is];
        check(!synthesized, [NSString stringWithFormat:@"%@: the port's ivar %@ is its own, not one synthesized for a declared property", className, ivar]);
    }
    free(ivars);
}

static CMSampleBufferRef bgra_sample(size_t width, size_t height)
{
    CVPixelBufferRef pixels = NULL;
    CVPixelBufferCreate(NULL, width, height, kCVPixelFormatType_32BGRA, NULL, &pixels);
    CMVideoFormatDescriptionRef format = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixels, &format);
    CMSampleTimingInfo timing = {kCMTimeInvalid, CMTimeMake(1, 30), kCMTimeInvalid};
    CMSampleBufferRef sample = NULL;
    CMSampleBufferCreateForImageBuffer(NULL, pixels, true, NULL, NULL, format, &timing, &sample);
    CFRelease(format);
    CVPixelBufferRelease(pixels);
    return sample;
}

// A JPEG of a picture with two colours, with an Exif user comment, and ImageIO's own thumbnail when asked.
static NSData *jpeg_file(size_t width, size_t height, BOOL thumbnail)
{
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, rgb, (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    CGContextSetRGBFillColor(context, 0.2, 0.5, 0.8, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextSetRGBFillColor(context, 0.9, 0.1, 0.1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width / 3, height / 2));
    CGImageRef image = CGBitmapContextCreateImage(context);
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, CFSTR("public.jpeg"), 1, NULL);
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)@{(id)kCGImagePropertyExifDictionary: @{(id)kCGImagePropertyExifUserComment: @"oracle"},
                                                                             (id)kCGImageDestinationEmbedThumbnail: @(thumbnail)});
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(rgb);
    return data;
}

static CMSampleBufferRef jpeg_file_sample(NSData *jpeg, int32_t width, int32_t height)
{
    CMBlockBufferRef block = NULL;
    CMBlockBufferCreateWithMemoryBlock(NULL, NULL, jpeg.length, NULL, NULL, 0, jpeg.length, kCMBlockBufferAssureMemoryNowFlag, &block);
    CMBlockBufferReplaceDataBytes(jpeg.bytes, block, 0, jpeg.length);
    CMVideoFormatDescriptionRef format = NULL;
    CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_JPEG, width, height, NULL, &format);
    size_t size = jpeg.length;
    CMSampleTimingInfo timing = {kCMTimeInvalid, CMTimeMake(1, 30), kCMTimeInvalid};
    CMSampleBufferRef sample = NULL;
    CMSampleBufferCreate(NULL, block, true, NULL, NULL, format, 1, 1, &timing, 1, &size, &sample);
    CFRelease(block);
    CFRelease(format);
    return sample;
}

static CMSampleBufferRef jpeg_sample(void)
{
    const char bytes[] = "not a picture, only a buffer marked JPEG";
    return jpeg_file_sample([NSData dataWithBytes:bytes length:sizeof bytes], 8, 8);
}

static void settingsChecks(void)
{
    // Defaults and every constructor.
    settingsSame(@"+photoSettings", @"+photoSettings", ^id(Class s, Class o) { return [s photoSettings]; });
    differs(@"+photoSettings stabilization", @"0", @"1", ^id(Class s, Class o) { return @([[s photoSettings] isAutoStillImageStabilizationEnabled]); });
    same(@"+photoSettings preview formats", ^id(Class s, Class o) { return [[[s photoSettings] availablePreviewPhotoPixelFormatTypes] componentsJoinedByString:@","]; });
    same(@"+photoSettings thumbnail codecs", ^id(Class s, Class o) { return [[[s photoSettings] availableEmbeddedThumbnailPhotoCodecTypes] componentsJoinedByString:@","]; });
    same(@"RAW-only thumbnail codecs", ^id(Class s, Class o) {
        return [[[s photoSettingsWithRawPixelFormatType:kCVPixelFormatType_14Bayer_RGGB] availableEmbeddedThumbnailPhotoCodecTypes] componentsJoinedByString:@","]; });
    differs(@"BGRA thumbnail codecs", @"jpeg", @"", ^id(Class s, Class o) {
        return [[[s photoSettingsWithFormat:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}] availableEmbeddedThumbnailPhotoCodecTypes] componentsJoinedByString:@","]; });
    differs(@"hvc1 thumbnail codecs", @"hvc1,jpeg", @"", ^id(Class s, Class o) {
        return [[[s photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecTypeHEVC}] availableEmbeddedThumbnailPhotoCodecTypes] componentsJoinedByString:@","]; });
    differs(@"RAW + JPEG RAW thumbnail codecs", @"jpeg", @"", ^id(Class s, Class o) {
        return [[[s photoSettingsWithRawPixelFormatType:kCVPixelFormatType_14Bayer_RGGB processedFormat:@{AVVideoCodecKey: AVVideoCodecTypeJPEG}]
                   availableRawEmbeddedThumbnailPhotoCodecTypes] componentsJoinedByString:@","]; });
    settingsSame(@"-init", @"-init", ^id(Class s, Class o) { return [[s alloc] init]; });
    NSDictionary *formats = @{@"nil": [NSNull null], @"BGRA": @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)},
                              @"420f": @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)},
                              @"hvc1": @{AVVideoCodecKey: AVVideoCodecTypeHEVC}, @"avc1": @{AVVideoCodecKey: AVVideoCodecTypeH264},
                              @"jpeg+quality": @{AVVideoCodecKey: AVVideoCodecTypeJPEG, AVVideoCompressionPropertiesKey: @{AVVideoQualityKey: @0.5}},
                              @"empty": @{}, @"no key": @{@"x": @1}, @"pixel format not a number": @{(id)kCVPixelBufferPixelFormatTypeKey: @"x"},
                              @"both keys": @{AVVideoCodecKey: AVVideoCodecTypeJPEG, (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}};
    for (NSString *name in [formats.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *format = formats[name] == [NSNull null] ? nil : formats[name];
        NSString *withFormat = [@"+photoSettingsWithFormat: " stringByAppendingString:name];
        settingsSame(withFormat, withFormat, ^id(Class s, Class o) { return [s photoSettingsWithFormat:format]; });
        NSString *rawProcessed = [@"+photoSettingsWithRawPixelFormatType:rgg4 processedFormat: " stringByAppendingString:name];
        settingsSame(rawProcessed, rawProcessed,
                     ^id(Class s, Class o) { return [s photoSettingsWithRawPixelFormatType:kCVPixelFormatType_14Bayer_RGGB processedFormat:format]; });
        NSString *processed = [@"+photoSettingsWithRawPixelFormatType:0 rawFileType:nil processedFormat: " stringByAppendingString:name];
        settingsSame(processed, processed,
                     ^id(Class s, Class o) { return [s photoSettingsWithRawPixelFormatType:0 rawFileType:nil processedFormat:format processedFileType:nil]; });
    }
    for (NSNumber *raw in @[@0, @(kCVPixelFormatType_14Bayer_GRBG), @(kCVPixelFormatType_14Bayer_RGGB), @(kCVPixelFormatType_14Bayer_BGGR),
                            @(kCVPixelFormatType_14Bayer_GBRG), @(kCVPixelFormatType_16VersatileBayer), @(kCVPixelFormatType_64RGBALE),
                            @(kCVPixelFormatType_32BGRA), @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)])
        settingsSame([NSString stringWithFormat:@"+photoSettingsWithRawPixelFormatType: %@", raw], [NSString stringWithFormat:@"+photoSettingsWithRawPixelFormatType: %@", raw],
                     ^id(Class s, Class o) { return [s photoSettingsWithRawPixelFormatType:raw.unsignedIntValue]; });
    NSArray *fileTypes = @[[NSNull null], AVFileTypeJPEG, AVFileTypeHEIC, AVFileTypeTIFF, AVFileTypeDNG];
    for (id rawType in fileTypes)
        for (id processedType in fileTypes)
            for (NSNumber *raw in @[@0, @(kCVPixelFormatType_14Bayer_RGGB)])
                for (id format in @[[NSNull null], @{AVVideoCodecKey: AVVideoCodecTypeJPEG}, @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}])
                {
                    // The RAW file type changes none of the three getters: a row is a RAW format, a processed format and its file type.
                    NSString *formatText = [[format description] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                    settingsSame([NSString stringWithFormat:@"+photoSettingsWithRawPixelFormatType:%@ rawFileType:%@ processedFormat:%@ processedFileType:%@", raw, rawType,
                                                            formatText, processedType],
                                 [NSString stringWithFormat:@"+photoSettingsWithRawPixelFormatType:%@ processedFormat:%@ processedFileType:%@", raw, formatText, processedType],
                                 ^id(Class s, Class o) {
                                     return [s photoSettingsWithRawPixelFormatType:raw.unsignedIntValue rawFileType:rawType == [NSNull null] ? nil : rawType
                                                                   processedFormat:format == [NSNull null] ? nil : format
                                                                 processedFileType:processedType == [NSNull null] ? nil : processedType];
                                 });
                }

    // Setters: what each takes, what it refuses, and what the settings answer after.
    typedef void (^Setter)(AVCapturePhotoSettings *);
    AVMutableMetadataItem *content = [AVMutableMetadataItem metadataItem];
    content.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    content.key = AVMetadataQuickTimeMetadataKeyContentIdentifier;
    content.value = @"the application's own";
    AVMutableMetadataItem *title = [AVMutableMetadataItem metadataItem];
    title.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    title.key = AVMetadataQuickTimeMetadataKeyTitle;
    title.value = @"a title";
    NSDictionary<NSString *, Setter> *setters = @{
        @"flashMode 7": ^(AVCapturePhotoSettings *s) { s.flashMode = (AVCaptureFlashMode)7; },
        @"autoRedEyeReductionEnabled YES": ^(AVCapturePhotoSettings *s) { s.autoRedEyeReductionEnabled = YES; },
        @"autoStillImageStabilizationEnabled YES": ^(AVCapturePhotoSettings *s) { s.autoStillImageStabilizationEnabled = YES; },
        @"autoStillImageStabilizationEnabled NO": ^(AVCapturePhotoSettings *s) { s.autoStillImageStabilizationEnabled = NO; },
        @"photoQualityPrioritization 0": ^(AVCapturePhotoSettings *s) { s.photoQualityPrioritization = 0; },
        @"photoQualityPrioritization 1": ^(AVCapturePhotoSettings *s) { s.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationSpeed; },
        @"photoQualityPrioritization 3": ^(AVCapturePhotoSettings *s) { s.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality; },
        @"photoQualityPrioritization 4": ^(AVCapturePhotoSettings *s) { s.photoQualityPrioritization = 4; },
        @"autoDualCameraFusionEnabled NO": ^(AVCapturePhotoSettings *s) { s.autoDualCameraFusionEnabled = NO; },
        @"autoVirtualDeviceFusionEnabled NO": ^(AVCapturePhotoSettings *s) { s.autoVirtualDeviceFusionEnabled = NO; },
        @"virtualDeviceConstituentPhotoDeliveryEnabledDevices []": ^(AVCapturePhotoSettings *s) { s.virtualDeviceConstituentPhotoDeliveryEnabledDevices = @[]; },
        @"maxPhotoDimensions 640x480": ^(AVCapturePhotoSettings *s) { s.maxPhotoDimensions = (CMVideoDimensions){640, 480}; },
        @"maxPhotoDimensions 640x480, then highResolutionPhotoEnabled YES": ^(AVCapturePhotoSettings *s) {
            s.maxPhotoDimensions = (CMVideoDimensions){640, 480}; s.highResolutionPhotoEnabled = YES; },
        @"maxPhotoDimensions 640x480, then highResolutionPhotoEnabled NO": ^(AVCapturePhotoSettings *s) {
            s.maxPhotoDimensions = (CMVideoDimensions){640, 480}; s.highResolutionPhotoEnabled = NO; },
        @"depthDataDeliveryEnabled YES": ^(AVCapturePhotoSettings *s) { s.depthDataDeliveryEnabled = YES; },
        @"embedsDepthDataInPhoto NO": ^(AVCapturePhotoSettings *s) { s.embedsDepthDataInPhoto = NO; },
        @"depthDataFiltered NO": ^(AVCapturePhotoSettings *s) { s.depthDataFiltered = NO; },
        @"cameraCalibrationDataDeliveryEnabled YES": ^(AVCapturePhotoSettings *s) { s.cameraCalibrationDataDeliveryEnabled = YES; },
        @"portraitEffectsMatteDeliveryEnabled YES": ^(AVCapturePhotoSettings *s) { s.portraitEffectsMatteDeliveryEnabled = YES; },
        @"embedsPortraitEffectsMatteInPhoto NO": ^(AVCapturePhotoSettings *s) { s.embedsPortraitEffectsMatteInPhoto = NO; },
        @"enabledSemanticSegmentationMatteTypes hair": ^(AVCapturePhotoSettings *s) { s.enabledSemanticSegmentationMatteTypes = @[AVSemanticSegmentationMatteTypeHair]; },
        @"embedsSemanticSegmentationMattesInPhoto NO": ^(AVCapturePhotoSettings *s) { s.embedsSemanticSegmentationMattesInPhoto = NO; },
        @"metadata {}": ^(AVCapturePhotoSettings *s) { s.metadata = @{}; },
        @"metadata Orientation": ^(AVCapturePhotoSettings *s) { s.metadata = @{(id)kCGImagePropertyOrientation: @6}; },
        @"metadata {Exif} {GPS}": ^(AVCapturePhotoSettings *s) {
            s.metadata = @{(id)kCGImagePropertyExifDictionary: @{(id)kCGImagePropertyExifUserComment: @"x"}, (id)kCGImagePropertyGPSDictionary: @{}}; },
        @"metadata PixelWidth DPIWidth ColorModel": ^(AVCapturePhotoSettings *s) {
            s.metadata = @{(id)kCGImagePropertyPixelWidth: @1, (id)kCGImagePropertyDPIWidth: @72, (id)kCGImagePropertyColorModel: @"RGB"}; },
        @"metadata {JFIF}": ^(AVCapturePhotoSettings *s) { s.metadata = @{(id)kCGImagePropertyJFIFDictionary: @{}}; },
        @"metadata NotAKey": ^(AVCapturePhotoSettings *s) { s.metadata = @{@"NotAKey": @1}; },
        @"livePhotoMovieFileURL http": ^(AVCapturePhotoSettings *s) { s.livePhotoMovieFileURL = [NSURL URLWithString:@"http://x/y.mov"]; },
        @"livePhotoVideoCodecType hvc1": ^(AVCapturePhotoSettings *s) { s.livePhotoVideoCodecType = AVVideoCodecTypeHEVC; },
        @"previewPhotoFormat BGRA": ^(AVCapturePhotoSettings *s) { s.previewPhotoFormat = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}; },
        @"previewPhotoFormat BGRA width only": ^(AVCapturePhotoSettings *s) {
            s.previewPhotoFormat = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA), (id)kCVPixelBufferWidthKey: @160}; },
        @"previewPhotoFormat no pixel format": ^(AVCapturePhotoSettings *s) { s.previewPhotoFormat = @{(id)kCVPixelBufferWidthKey: @160}; },
        @"previewPhotoFormat nil": ^(AVCapturePhotoSettings *s) { s.previewPhotoFormat = nil; },
        @"embeddedThumbnailPhotoFormat nil": ^(AVCapturePhotoSettings *s) { s.embeddedThumbnailPhotoFormat = nil; },
        @"embeddedThumbnailPhotoFormat no codec": ^(AVCapturePhotoSettings *s) { s.embeddedThumbnailPhotoFormat = @{AVVideoWidthKey: @1}; },
        @"embeddedThumbnailPhotoFormat pixel format": ^(AVCapturePhotoSettings *s) {
            s.embeddedThumbnailPhotoFormat = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}; },
        @"embeddedThumbnailPhotoFormat hvc1": ^(AVCapturePhotoSettings *s) { s.embeddedThumbnailPhotoFormat = @{AVVideoCodecKey: AVVideoCodecTypeHEVC}; },
        @"embeddedThumbnailPhotoFormat jpeg": ^(AVCapturePhotoSettings *s) { s.embeddedThumbnailPhotoFormat = @{AVVideoCodecKey: AVVideoCodecTypeJPEG}; },
        @"embeddedThumbnailPhotoFormat jpeg 320x240": ^(AVCapturePhotoSettings *s) {
            s.embeddedThumbnailPhotoFormat = @{AVVideoCodecKey: AVVideoCodecTypeJPEG, AVVideoWidthKey: @320, AVVideoHeightKey: @240}; },
        @"rawEmbeddedThumbnailPhotoFormat nil": ^(AVCapturePhotoSettings *s) { s.rawEmbeddedThumbnailPhotoFormat = nil; },
        @"rawEmbeddedThumbnailPhotoFormat no codec": ^(AVCapturePhotoSettings *s) { s.rawEmbeddedThumbnailPhotoFormat = @{AVVideoWidthKey: @1}; },
        @"rawEmbeddedThumbnailPhotoFormat jpeg": ^(AVCapturePhotoSettings *s) { s.rawEmbeddedThumbnailPhotoFormat = @{AVVideoCodecKey: AVVideoCodecTypeJPEG}; },
        @"autoContentAwareDistortionCorrectionEnabled YES": ^(AVCapturePhotoSettings *s) { s.autoContentAwareDistortionCorrectionEnabled = YES; },
    };
    for (NSString *name in [setters.allKeys sortedArrayUsingSelector:@selector(compare:)])
        settingsSame([@"set " stringByAppendingString:name], divergences()[[@"set " stringByAppendingString:name]] ? [@"set " stringByAppendingString:name] : @"+photoSettings", ^id(Class s, Class o) {
            AVCapturePhotoSettings *settings = [s photoSettings];
            setters[name](settings);
            return settings;
        });
    // A 420f preview, and the metadata's {MakerApple}, which the host takes: the port takes both.
    same(@"set previewPhotoFormat 420f",
         ^id(Class s, Class o) { ((AVCapturePhotoSettings *)[s photoSettings]).previewPhotoFormat = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)}; return @"ok"; });
    same(@"set metadata {MakerApple}", ^id(Class s, Class o) {
        AVCapturePhotoSettings *settings = [s photoSettings];
        settings.metadata = @{@"{MakerApple}": @{@"1": @1}};
        return settings.metadata;
    });

    // The Live Photo movie metadata: the settings' own content identifier, last; the application may not give one.
    same(@"livePhotoMovieMetadata", ^id(Class s, Class o) {
        AVCapturePhotoSettings *settings = [s photoSettings];
        NSMutableArray *log = [NSMutableArray array];
        void (^items)(NSString *) = ^(NSString *label) {
            NSMutableArray *keys = [NSMutableArray array];
            for (AVMetadataItem *item in settings.livePhotoMovieMetadata)
                [keys addObject:[NSString stringWithFormat:@"%@/%@ %@", item.keySpace, item.key, [item.value isKindOfClass:[NSString class]] ? @"string" : @"?"]];
            [log addObject:[NSString stringWithFormat:@"%@: %@", label, [keys componentsJoinedByString:@", "]]];
        };
        items(@"default");
        NSString *identifier = (id)settings.livePhotoMovieMetadata.lastObject.value;
        settings.livePhotoMovieMetadata = @[title];
        items(@"[title]");
        [log addObject:[NSString stringWithFormat:@"same identifier %d", [(id)settings.livePhotoMovieMetadata.lastObject.value isEqual:identifier]]];
        settings.livePhotoMovieMetadata = nil;
        items(@"nil");
        [log addObject:answer(^{ settings.livePhotoMovieMetadata = @[content]; return @"ok"; })];
        AVCapturePhotoSettings *other = [s photoSettings];
        [log addObject:[NSString stringWithFormat:@"another settings shares it %d, a copy %d, one from it %d",
                                                  [(id)other.livePhotoMovieMetadata.lastObject.value isEqual:identifier],
                                                  [(id)[(AVCapturePhotoSettings *)[settings copy] livePhotoMovieMetadata].lastObject.value isEqual:identifier],
                                                  [(id)((AVCapturePhotoSettings *)[s photoSettingsFromPhotoSettings:settings]).livePhotoMovieMetadata.lastObject.value isEqual:identifier]]];
        return [log componentsJoinedByString:@"; "];
    });

    // A copy is the same request; +photoSettingsFromPhotoSettings: a new one with every setting.
    same(@"copy and photoSettingsFromPhotoSettings:", ^id(Class s, Class o) {
        AVCapturePhotoSettings *settings = [s photoSettingsWithRawPixelFormatType:kCVPixelFormatType_14Bayer_RGGB processedFormat:@{AVVideoCodecKey: AVVideoCodecTypeJPEG}];
        settings.flashMode = AVCaptureFlashModeAuto;
        settings.metadata = @{(id)kCGImagePropertyOrientation: @3};
        settings.previewPhotoFormat = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA), (id)kCVPixelBufferWidthKey: @16, (id)kCVPixelBufferHeightKey: @16};
        settings.highResolutionPhotoEnabled = YES;
        settings.depthDataDeliveryEnabled = YES;
        settings.livePhotoMovieFileURL = [NSURL fileURLWithPath:@"/tmp/x.mov"];
        AVCapturePhotoSettings *copy = [settings copy], *from = [s photoSettingsFromPhotoSettings:settings];
        return [NSString stringWithFormat:@"copy: class %d, same object %d, same ID %d, every setting %d; from: class %d, new ID %d, every setting %d",
                                          [copy class] == s, copy == settings, copy.uniqueID == settings.uniqueID, [fullDump(copy) isEqualToString:fullDump(settings)],
                                          [from class] == s, from.uniqueID > settings.uniqueID, [fullDump(from) isEqualToString:fullDump(settings)]];
    });
    same(@"NSCopying", ^id(Class s, Class o) { return @([s conformsToProtocol:@protocol(NSCopying)]); });
    same(@"unique IDs", ^id(Class s, Class o) {
        AVCapturePhotoSettings *a = [s photoSettings], *b = [s photoSettingsWithFormat:nil], *c = [[s alloc] init];
        return [NSString stringWithFormat:@"increasing %d", a.uniqueID < b.uniqueID && b.uniqueID < c.uniqueID];
    });
}

static void outputChecks(void)
{
    NSArray *outputGetters = getters(@"AVCapturePhotoOutput", [NSSet setWithObjects:@"init", @"preparedPhotoSettingsArray", nil]);
    same(@"a new output", ^id(Class s, Class o) { return dump([o new], outputGetters); });
    same(@"its prepared settings' count", ^id(Class s, Class o) { return @([[o new] preparedPhotoSettingsArray].count); });
    settingsSame(@"its prepared settings", @"its prepared settings", ^id(Class s, Class o) { return [[o new] preparedPhotoSettingsArray].firstObject; });
    NSDictionary<NSString *, void (^)(AVCapturePhotoOutput *)> *setters = @{
        @"appleProRAWEnabled YES": ^(AVCapturePhotoOutput *x) { x.appleProRAWEnabled = YES; },
        @"appleProRAWEnabled NO": ^(AVCapturePhotoOutput *x) { x.appleProRAWEnabled = NO; },
        @"maxPhotoQualityPrioritization 0": ^(AVCapturePhotoOutput *x) { x.maxPhotoQualityPrioritization = 0; },
        @"maxPhotoQualityPrioritization 1": ^(AVCapturePhotoOutput *x) { x.maxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationSpeed; },
        @"maxPhotoQualityPrioritization 3": ^(AVCapturePhotoOutput *x) { x.maxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality; },
        @"maxPhotoQualityPrioritization 4": ^(AVCapturePhotoOutput *x) { x.maxPhotoQualityPrioritization = 4; },
        @"virtualDeviceConstituentPhotoDeliveryEnabled YES": ^(AVCapturePhotoOutput *x) { x.virtualDeviceConstituentPhotoDeliveryEnabled = YES; },
        @"virtualDeviceConstituentPhotoDeliveryEnabled NO": ^(AVCapturePhotoOutput *x) { x.virtualDeviceConstituentPhotoDeliveryEnabled = NO; },
        @"dualCameraDualPhotoDeliveryEnabled YES": ^(AVCapturePhotoOutput *x) { x.dualCameraDualPhotoDeliveryEnabled = YES; },
        @"dualCameraDualPhotoDeliveryEnabled NO": ^(AVCapturePhotoOutput *x) { x.dualCameraDualPhotoDeliveryEnabled = NO; },
        @"highResolutionCaptureEnabled YES": ^(AVCapturePhotoOutput *x) { x.highResolutionCaptureEnabled = YES; },
        @"maxPhotoDimensions 0x0": ^(AVCapturePhotoOutput *x) { x.maxPhotoDimensions = (CMVideoDimensions){0, 0}; },
        @"maxPhotoDimensions 640x480": ^(AVCapturePhotoOutput *x) { x.maxPhotoDimensions = (CMVideoDimensions){640, 480}; },
        @"livePhotoCaptureEnabled YES": ^(AVCapturePhotoOutput *x) { x.livePhotoCaptureEnabled = YES; },
        @"livePhotoCaptureEnabled NO": ^(AVCapturePhotoOutput *x) { x.livePhotoCaptureEnabled = NO; },
        @"livePhotoCaptureSuspended YES": ^(AVCapturePhotoOutput *x) { x.livePhotoCaptureSuspended = YES; },
        @"livePhotoCaptureSuspended NO": ^(AVCapturePhotoOutput *x) { x.livePhotoCaptureSuspended = NO; },
        @"preservesLivePhotoCaptureSuspendedOnSessionStop YES": ^(AVCapturePhotoOutput *x) { x.preservesLivePhotoCaptureSuspendedOnSessionStop = YES; },
        @"preservesLivePhotoCaptureSuspendedOnSessionStop NO": ^(AVCapturePhotoOutput *x) { x.preservesLivePhotoCaptureSuspendedOnSessionStop = NO; },
        @"livePhotoAutoTrimmingEnabled YES": ^(AVCapturePhotoOutput *x) { x.livePhotoAutoTrimmingEnabled = YES; },
        @"livePhotoAutoTrimmingEnabled NO": ^(AVCapturePhotoOutput *x) { x.livePhotoAutoTrimmingEnabled = NO; },
        @"contentAwareDistortionCorrectionEnabled YES": ^(AVCapturePhotoOutput *x) { x.contentAwareDistortionCorrectionEnabled = YES; },
        @"contentAwareDistortionCorrectionEnabled NO": ^(AVCapturePhotoOutput *x) { x.contentAwareDistortionCorrectionEnabled = NO; },
        @"depthDataDeliveryEnabled YES": ^(AVCapturePhotoOutput *x) { x.depthDataDeliveryEnabled = YES; },
        @"depthDataDeliveryEnabled NO": ^(AVCapturePhotoOutput *x) { x.depthDataDeliveryEnabled = NO; },
        @"portraitEffectsMatteDeliveryEnabled YES": ^(AVCapturePhotoOutput *x) { x.portraitEffectsMatteDeliveryEnabled = YES; },
        @"portraitEffectsMatteDeliveryEnabled NO": ^(AVCapturePhotoOutput *x) { x.portraitEffectsMatteDeliveryEnabled = NO; },
        @"enabledSemanticSegmentationMatteTypes hair": ^(AVCapturePhotoOutput *x) { x.enabledSemanticSegmentationMatteTypes = @[AVSemanticSegmentationMatteTypeHair]; },
        @"enabledSemanticSegmentationMatteTypes []": ^(AVCapturePhotoOutput *x) { x.enabledSemanticSegmentationMatteTypes = @[]; },
        @"photoSettingsForSceneMonitoring nil": ^(AVCapturePhotoOutput *x) { x.photoSettingsForSceneMonitoring = nil; },
    };
    for (NSString *name in [setters.allKeys sortedArrayUsingSelector:@selector(compare:)])
        same([@"output set " stringByAppendingString:name], ^id(Class s, Class o) {
            AVCapturePhotoOutput *output = [o new];
            NSString *result = answer(^{ setters[name](output); return @"ok"; });
            return [NSString stringWithFormat:@"%@; %@", result, dump(output, outputGetters)];
        });
    same(@"photoSettingsForSceneMonitoring", ^id(Class s, Class o) {
        AVCapturePhotoOutput *output = [o new];
        AVCapturePhotoSettings *settings = [s photoSettings];
        output.photoSettingsForSceneMonitoring = settings;
        AVCapturePhotoSettings *held = output.photoSettingsForSceneMonitoring;
        return [NSString stringWithFormat:@"same object %d, same ID %d, same settings %d, flash scene %d, stabilization scene %d", held == settings,
                                          held.uniqueID == settings.uniqueID, [fullDump(held) isEqualToString:fullDump(settings)],
                                          output.isFlashScene, output.isStillImageStabilizationScene];
    });
    same(@"setPreparedPhotoSettingsArray:completionHandler: with no session", ^id(Class s, Class o) {
        AVCapturePhotoOutput *output = [o new];
        AVCapturePhotoSettings *first = [s photoSettings], *second = [s photoSettingsWithFormat:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
        NSMutableArray *calls = [NSMutableArray array];
        [output setPreparedPhotoSettingsArray:@[first] completionHandler:^(BOOL prepared, NSError *error) {
            @synchronized (calls) { [calls addObject:[NSString stringWithFormat:@"first %d %@", prepared, error]]; }
        }];
        [output setPreparedPhotoSettingsArray:@[second] completionHandler:^(BOOL prepared, NSError *error) {
            @synchronized (calls) { [calls addObject:[NSString stringWithFormat:@"second %d %@", prepared, error]]; }
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        AVCapturePhotoSettings *held = output.preparedPhotoSettingsArray.firstObject;
        @synchronized (calls) {
            return [NSString stringWithFormat:@"calls [%@]; holds %lu, the second's ID %d, a copy %d, its settings %d", [calls componentsJoinedByString:@", "],
                                              (unsigned long)output.preparedPhotoSettingsArray.count, held.uniqueID == second.uniqueID, held != second,
                                              [fullDump(held) isEqualToString:fullDump(second)]];
        }
    });
    for (NSString *fileType in @[AVFileTypeJPEG, AVFileTypeTIFF, AVFileTypeHEIC, AVFileTypeDNG, @"x.y"])
        same([@"supported types for " stringByAppendingString:fileType], ^id(Class s, Class o) {
            AVCapturePhotoOutput *output = [o new];
            return [NSString stringWithFormat:@"%@ %@ %@", [output supportedPhotoPixelFormatTypesForFileType:fileType],
                                              [output supportedPhotoCodecTypesForFileType:fileType], [output supportedRawPhotoPixelFormatTypesForFileType:fileType]];
        });
    same(@"RAW pixel formats, every one CoreVideo describes", ^id(Class s, Class o) {
        NSMutableArray *raw = [NSMutableArray array];
        for (NSNumber *type in CFBridgingRelease(CVPixelFormatDescriptionArrayCreateWithAllPixelFormatTypes(NULL))) {
            BOOL bayer = [o isBayerRAWPixelFormat:type.unsignedIntValue], pro = [o isAppleProRAWPixelFormat:type.unsignedIntValue];
            if (bayer || pro)
                [raw addObject:[NSString stringWithFormat:@"%@=%d/%d", type, bayer, pro]];
        }
        return [raw componentsJoinedByString:@" "];
    });
    same(@"capture with no session", ^id(Class s, Class o) {
        [[o new] capturePhotoWithSettings:[s photoSettings] delegate:(id)[NSObject new]];
        return @"ok";
    });
    CMSampleBufferRef bgra = bgra_sample(32, 24), jpeg = jpeg_sample();
    same(@"JPEG representation of an uncompressed buffer", ^id(Class s, Class o) { return [o JPEGPhotoDataRepresentationForJPEGSampleBuffer:bgra previewPhotoSampleBuffer:NULL]; });
    same(@"DNG representation of a JPEG buffer", ^id(Class s, Class o) { return [o DNGPhotoDataRepresentationForRawSampleBuffer:jpeg previewPhotoSampleBuffer:NULL]; });
    CFRelease(bgra);
    CFRelease(jpeg);

    // The JPEG of a photo with a preview holds the preview as its Exif thumbnail (IFD1), no longer on its longest side
    // than the host's writes it; with no preview, no thumbnail.
    size_t photos[][2] = {{640, 480}, {3264, 2448}}, previews[][2] = {{32, 24}, {160, 120}, {640, 480}, {1600, 1200}, {200, 200}, {120, 160}};
    for (int p = 0; p < 2; p++) {
        CMSampleBufferRef photo = jpeg_file_sample(jpeg_file(photos[p][0], photos[p][1], NO), (int32_t)photos[p][0], (int32_t)photos[p][1]);
        same([NSString stringWithFormat:@"JPEG representation of a %zux%zu JPEG, no preview", photos[p][0], photos[p][1]],
             ^id(Class s, Class o) { return jpeg_contents([o JPEGPhotoDataRepresentationForJPEGSampleBuffer:photo previewPhotoSampleBuffer:NULL]); });
        for (int v = 0; v < 6; v++) {
            CMSampleBufferRef preview = bgra_sample(previews[v][0], previews[v][1]);
            same([NSString stringWithFormat:@"JPEG representation of a %zux%zu JPEG, preview %zux%zu", photos[p][0], photos[p][1], previews[v][0], previews[v][1]],
                 ^id(Class s, Class o) { return jpeg_contents([o JPEGPhotoDataRepresentationForJPEGSampleBuffer:photo previewPhotoSampleBuffer:preview]); });
            CFRelease(preview);
        }
        CFRelease(photo);
    }
    // A sample whose own JPEG carries a thumbnail, with no preview: the host's repackaging drops it, the port's keeps
    // it, as the thumbnail its capture embeds on request (facts, "The embedded thumbnail").
    CMSampleBufferRef carrying = jpeg_file_sample(jpeg_file(640, 480, YES), 640, 480);
    differs(@"JPEG representation of a JPEG carrying a thumbnail, no preview", @"640x480 comment oracle; no IFD1",
            @"640x480 comment oracle; IFD1 0103/3/1=6 011a/5/1=72/1 011b/5/1=72/1 0128/3/1=2 0201/4/1=set 0202/4/1=set next 0; thumbnail APP0 thumbnail 160x120",
            ^id(Class s, Class o) { return jpeg_contents([o JPEGPhotoDataRepresentationForJPEGSampleBuffer:carrying previewPhotoSampleBuffer:NULL]); });
    CFRelease(carrying);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: oracle <declared-members>\n");
            return 2;
        }
        hostSettings = [AVCapturePhotoSettings class];
        portSettings = NSClassFromString(@"CharonHostAVCapturePhotoSettings");
        hostOutput = [AVCapturePhotoOutput class];
        portOutput = NSClassFromString(@"CharonHostAVCapturePhotoOutput");
        check(hostSettings && portSettings && hostOutput && portOutput && hostSettings != portSettings && hostOutput != portOutput,
              @"the host's classes and the port's are all here, apart");
        NSMutableDictionary *rows = [NSMutableDictionary dictionary];
        for (NSString *line in [[NSString stringWithContentsOfFile:@(argv[2]) encoding:NSUTF8StringEncoding error:NULL] componentsSeparatedByString:@"\n"]) {
            NSArray *fields = [line componentsSeparatedByString:@"\t"];
            if (fields.count == 3)
                rows[fields[0]] = @[fields[1], fields[2]];
        }
        divergenceRows = rows;
        declared = [NSMutableDictionary dictionary];
        NSString *list = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:NULL];
        for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
            NSRange space = [line rangeOfString:@" "];
            if (space.location == NSNotFound)
                continue;
            NSString *owner = [line substringToIndex:space.location];
            if (!declared[owner])
                declared[owner] = [NSMutableArray array];
            [declared[owner] addObject:[line substringFromIndex:space.location + 1]];
        }
        check(declared[@"AVCapturePhotoSettings"].count > 30 && declared[@"AVCapturePhotoOutput"].count > 60,
              [NSString stringWithFormat:@"the SDK header declares %lu members of the settings and %lu of the output",
                                         (unsigned long)declared[@"AVCapturePhotoSettings"].count, (unsigned long)declared[@"AVCapturePhotoOutput"].count]);
        members(@"AVCapturePhotoSettings", hostSettings, portSettings);
        members(@"AVCapturePhotoOutput", hostOutput, portOutput);
        settingsChecks();
        outputChecks();
        printf("%d checks, %d failed\n", checks, failures);
    }
    return failures ? 1 : 0;
}
