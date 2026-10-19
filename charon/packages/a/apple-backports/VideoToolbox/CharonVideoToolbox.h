#ifndef CHARON_VIDEOTOOLBOX_H
#define CHARON_VIDEOTOOLBOX_H

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#ifndef CHARON_VT_DECLARE_FOR_CASE
#import <VideoToolbox/VideoToolbox.h>
#endif

// The frame processor of SDK 26.0, which the lowered 16.4 SDK this package builds against does not
// declare at all - neither the two protocols, nor the seventeen classes, nor the two enumerations
// they use. The same arrangement CharonSensorKit.h has: the same declarations the SDK makes, the same
// property types, no ivars, and the availability and refined-for-Swift annotations left out, which mean
// nothing in a translation unit that is not an application's.
//
// Two shapes are worth naming, because both cost an afternoon elsewhere in this delivery:
//
//   - the two PROTOCOLS carry the shared properties, and the seventeen classes CONFORM to one of them.
//     A class the port defines inherits that conformance, so every property a protocol declares still
//     needs an accessor written for the store: a @dynamic in a class implementation would leave the
//     compiler auto-synthesising a getter that reads an ivar nothing ever writes;
//   - and two of the protocol's properties are CLASS properties, and one of them is a CMVideoDimensions
//     - a struct, which can be neither cast out of the store the way an object can nor put in a
//     dictionary, so it is held as an NSValue over its own bytes.

NS_ASSUME_NONNULL_BEGIN

// Everything below is the port's own declaration of what the 16.4 SDK does not have. A host comparison
// compiles the port's VALUE FILE with -DCHARON_HOST_DIFFERENTIAL and therefore takes the host's own
// declarations of the same classes - the host's VideoToolbox does declare them, as macOS-available -
// so redeclaring them in the same translation unit is a duplicate declaration, eleven of them, and the
// compiler says so. This is the same guard CharonMetricKit.h and the SensorKit case file use, for the
// same reason: what the port declares is for the armv7 build, and a host comparison is not it.
// The guard below is there because the HOST declares these classes too, as macOS-available, and two
// declarations of one class in one translation unit is a duplicate declaration. It is not turned off for
// the whole port build: it is turned off only for a translation unit that does NOT also include the
// system's VideoToolbox header, which is what the differential's case is. CHARON_VT_DECLARE_FOR_CASE is
// that translation unit, and it is how the case can write [VTMotionBlurConfiguration alloc] directly
// instead of reaching for the runtime and a string - a class it can name should be called by name.
//
// The case translation unit does not import VideoToolbox, so the SDK's own types of the session and callback
// API are missing from it. They are declared here for that unit only, from the generator's declarations table
// (spec/VideoToolbox/declarations.tsv). The port build imports VideoToolbox and takes them from there, and a
// second typedef of the enum-typed flags would clash with the SDK's own declaration.
#ifdef CHARON_VT_DECLARE_FOR_CASE
// The flags are the SDK's enums with their fixed underlying types, forward-declared the way the SDK then defines them
// (CF_OPTIONS), so that a translation unit that also imports the SDK's header sees one enum, not a typedef clashing with it.
enum VTDecodeInfoFlags : UInt32;
typedef enum VTDecodeInfoFlags VTDecodeInfoFlags;
enum VTDecodeFrameFlags : uint32_t;
typedef enum VTDecodeFrameFlags VTDecodeFrameFlags;
enum VTEncodeInfoFlags : UInt32;
typedef enum VTEncodeInfoFlags VTEncodeInfoFlags;
typedef struct OpaqueVTDecompressionSession *VTDecompressionSessionRef;
typedef struct OpaqueVTCompressionSession *VTCompressionSessionRef;
#if defined(__BLOCKS__)
typedef void (^VTDecompressionOutputHandler)(OSStatus, VTDecodeInfoFlags, CVImageBufferRef, CMTime, CMTime);
typedef void (^VTCompressionOutputHandler)(OSStatus, VTEncodeInfoFlags, CMSampleBufferRef);
#endif
#endif

#if !defined(CHARON_HOST_DIFFERENTIAL) || defined(CHARON_VT_DECLARE_FOR_CASE)

// The one protocol of another framework this header names. `-processWithCommandBuffer:parameters:`
// takes an `id<MTLCommandBuffer>` because that is what SDK 26.2's VTFrameProcessor.h writes, and the
// header that declares it (Metal) is a framework this library does not link: the port never sends a
// message to the buffer, so it needs the name and not the interface. A forward declaration is the
// same arrangement CharonMediaPlayerProtocols.h and CharonWebExtension.h use for the same reason.
@protocol MTLCommandBuffer;

// The multi-image decode and encode variants, which SDK 26.2 declares at 17.0 and 18.0 and the 16.4 SDK
// does not declare at all (measured: the 16.4 SDK's VTDecompressionSession.h and VTCompressionSession.h name
// none of the six, and the 4.3 and 6.1.3 armv7 caches export none of the six either - tools/corpus/
// dump-cache.lua and v-audio's 6.1.3 dump, 2026-10-03). The signatures are transcribed from SDK 26.2 with
// the availability annotations left out, and they need one type the 16.4 SDK does not have:
// CMTaggedBufferGroup, which arrived with iOS 14 and is named here because three of the six take it. It is
// an OPAQUE type in those signatures - every use below is a pointer the caller owns - so a forward
// declaration is the whole of it, the same arrangement CharonMediaPlayerProtocols.h makes for a type from
// a framework this library does not link.
typedef struct OpaqueCMTaggedBufferGroup *CMTaggedBufferGroupRef;

// SDK 26.2, VTDecompressionSession.h:380-384. The multi-image callback receives a CMTaggedBufferGroup
// where the single-image callback of the 16.4 SDK receives a CVImageBuffer, and that difference is the whole
// of the family: no release the port builds can call it, because its own decode callback has no such
// parameter.
typedef void (*VTDecompressionOutputMultiImageCallback)(
    void * CM_NULLABLE decompressionOutputMultiImageRefCon,
    void * CM_NULLABLE sourceFrameRefCon,
    OSStatus status,
    VTDecodeInfoFlags infoFlags,
    CMTaggedBufferGroupRef CM_NULLABLE taggedBufferGroup,
    CMTime presentationTimeStamp,
    CMTime presentationDuration);

#if defined(__BLOCKS__)
// SDK 26.2, VTDecompressionSession.h:432-439.
typedef void (^VTDecompressionMultiImageCapableOutputHandler)(
    OSStatus status,
    VTDecodeInfoFlags infoFlags,
    CVImageBufferRef CM_NULLABLE imageBuffer,
    CMTaggedBufferGroupRef CM_NULLABLE taggedBufferGroup,
    CMTime presentationTimeStamp,
    CMTime presentationDuration);
#endif

extern OSStatus VTDecompressionSessionSetMultiImageCallback(
    VTDecompressionSessionRef CM_NONNULL decompressionSession,
    VTDecompressionOutputMultiImageCallback CM_NONNULL outputMultiImageCallback,
    void * CM_NULLABLE outputMultiImageRefcon);

extern OSStatus VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut,
    VTDecompressionMultiImageCapableOutputHandler CM_NONNULL multiImageCapableOutputHandler);

extern OSStatus VTDecompressionSessionDecodeFrameWithOptions(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    CFDictionaryRef CM_NULLABLE frameOptions,
    void * CM_NULLABLE sourceFrameRefCon,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut);

extern OSStatus VTDecompressionSessionDecodeFrameWithOptionsAndOutputHandler(
    VTDecompressionSessionRef CM_NONNULL session,
    CMSampleBufferRef CM_NONNULL sampleBuffer,
    VTDecodeFrameFlags decodeFlags,
    CFDictionaryRef CM_NULLABLE frameOptions,
    VTDecodeInfoFlags * CM_NULLABLE infoFlagsOut,
    VTDecompressionOutputHandler CM_NONNULL outputHandler);

extern OSStatus VTCompressionSessionEncodeMultiImageFrame(
    VTCompressionSessionRef CM_NONNULL session,
    CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CMTime presentationTimeStamp,
    CMTime duration,
    CFDictionaryRef CM_NULLABLE frameProperties,
    void * CM_NULLABLE sourceFrameRefcon,
    VTEncodeInfoFlags * CM_NULLABLE infoFlagsOut);

#if defined(__BLOCKS__)
extern OSStatus VTCompressionSessionEncodeMultiImageFrameWithOutputHandler(
    VTCompressionSessionRef CM_NONNULL session,
    CMTaggedBufferGroupRef CM_NONNULL taggedBufferGroup,
    CMTime presentationTimeStamp,
    CMTime duration,
    CFDictionaryRef CM_NULLABLE frameProperties,
    VTEncodeInfoFlags * CM_NULLABLE infoFlagsOut,
    VTCompressionOutputHandler CM_NONNULL outputHandler);
#endif

// The declaration of kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder that used to be
// here is gone with the function that used it. Nothing in the port references the key any more: the row that
// did - VTIsHardwareDecodeSupported - is OWED, not implemented, and the measurement that moved it is in
// facts/VideoToolbox/Queries.md. The 16.4 SDK still hides the key from an armv7 build
// (VTDecompressionProperties.h:140-184 wraps the whole kVTVideoDecoderSpecification_* block in
// `#if !TARGET_OS_IPHONE`), so anything that needs it again has to declare it again, transcribed from SDK
// 26.2 line 172, and that declaration has to arrive with the row that uses it.

// The error domain VTFrameProcessor.h and VTFrameProcessorErrors.h of SDK 26.2 declare, and the codes
// the second of them enumerates, transcribed with Apple's own values: a caller compares a code against
// these names, so they are part of the surface the port carries and not an implementation detail. The
// domain's string is NOT the header's to spell - it is measured from the host's own VideoToolbox by
// dlsym and recorded in facts/VideoToolbox/FrameProcessorErrors.md.
extern NSErrorDomain _Nonnull const VTFrameProcessorErrorDomain;

typedef NS_ENUM(NSInteger, VTFrameProcessorError) {
    VTFrameProcessorUnknownError = -19730,
    VTFrameProcessorUnsupportedResolution = -19731,
    VTFrameProcessorSessionNotStarted = -19732,
    VTFrameProcessorSessionAlreadyActive = -19733,
    VTFrameProcessorFatalError = -19734,
    VTFrameProcessorSessionLevelError = -19735,
    VTFrameProcessorInitializationFailed = -19736,
    VTFrameProcessorUnsupportedInput = -19737,
    VTFrameProcessorMemoryAllocationFailure = -19738,
    VTFrameProcessorRevisionNotSupported = -19739,
    VTFrameProcessorProcessingError = -19740,
    VTFrameProcessorInvalidParameterError = -19741,
    VTFrameProcessorInvalidFrameTiming = -19742,
    VTFrameProcessorAssetDownloadFailed = -19743,
};

// The HDR per-frame metadata generation session of SDK 26.2, which arrived with iOS 18.0 and which the
// 16.4 SDK this package builds against does not declare at all - not the type, not the three functions,
// not the format constant. They are declared here for the same reason the seventeen classes above are:
// without a declaration a caller cannot name the function, so there is nothing to export a symbol FOR.
//
// The types are spelled as SDK 26.2 spells them. VTHDRPerFrameMetadataGenerationSessionRef is a
// CF-bridged opaque type there, and the armv7 build has no ObjC class of that name to bridge to, so it
// is the plain CF spelling - an opaque struct pointer - which is what every other non-bridged CF type in
// CoreFoundation is.
typedef CFStringRef VTHDRPerFrameMetadataGenerationHDRFormatType;

typedef struct OpaqueVTHDRPerFrameMetadataGenerationSession *VTHDRPerFrameMetadataGenerationSessionRef;

extern const VTHDRPerFrameMetadataGenerationHDRFormatType
    kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision;

extern CFTypeID VTHDRPerFrameMetadataGenerationSessionGetTypeID(void);

extern OSStatus VTHDRPerFrameMetadataGenerationSessionCreate(
    CM_NULLABLE CFAllocatorRef allocator, float framesPerSecond, CM_NULLABLE CFDictionaryRef options,
    CM_RETURNS_RETAINED_PARAMETER CM_NULLABLE VTHDRPerFrameMetadataGenerationSessionRef * CM_NONNULL
        hdrPerFrameMetadataGenerationSessionOut);

extern OSStatus VTHDRPerFrameMetadataGenerationSessionAttachMetadata(
    VTHDRPerFrameMetadataGenerationSessionRef hdrPerFrameMetadataGenerationSession,
    CVPixelBufferRef pixelBuffer, Boolean sceneChange);

@class VTFrameProcessor;
@class VTFrameProcessorFrame;
@class VTFrameProcessorOpticalFlow;
@class VTFrameRateConversionConfiguration;
@class VTFrameRateConversionParameters;
@class VTLowLatencyFrameInterpolationConfiguration;
@class VTLowLatencyFrameInterpolationParameters;
@class VTLowLatencySuperResolutionScalerConfiguration;
@class VTLowLatencySuperResolutionScalerParameters;
@class VTMotionBlurConfiguration;
@class VTMotionBlurParameters;
@class VTOpticalFlowConfiguration;
@class VTOpticalFlowParameters;
@class VTSuperResolutionScalerConfiguration;
@class VTSuperResolutionScalerParameters;
@class VTTemporalNoiseFilterConfiguration;
@class VTTemporalNoiseFilterParameters;

// The 14 enumerations the seventeen classes use, with the enumerators and the values the iOS 26.2
// headers give them. The template commit carried two of them as typedefs of their underlying type with
// no enumerator list, which was wrong twice over: it dropped the names an application writes
// (VTMotionBlurConfigurationRevision1 is a call site, not a number), and the SDK does enumerate them,
// so there was a truth to copy. These are copied from the headers, not invented, and the differential
// below checks the port's answers against the host's own for the two families the host agrees on.
typedef NS_ENUM(NSInteger, VTFrameRateConversionConfigurationQualityPrioritization) {
    VTFrameRateConversionConfigurationQualityPrioritizationNormal = 1,
    VTFrameRateConversionConfigurationQualityPrioritizationQuality = 2,
} NS_SWIFT_NAME(VTFrameRateConversionQualityPrioritization);

typedef NS_ENUM(NSInteger, VTFrameRateConversionConfigurationRevision) {
    VTFrameRateConversionConfigurationRevision1 = 1,
} NS_SWIFT_NAME(VTFrameRateConversionRevision);

typedef NS_ENUM(NSInteger, VTFrameRateConversionParametersSubmissionMode) {
    VTFrameRateConversionParametersSubmissionModeRandom = 1,
    VTFrameRateConversionParametersSubmissionModeSequential = 2,
    VTFrameRateConversionParametersSubmissionModeSequentialReferencesUnchanged = 3,
} NS_SWIFT_NAME(VTFrameRateConversionSubmissionMode);

typedef NS_ENUM(NSInteger, VTMotionBlurConfigurationQualityPrioritization) {
    VTMotionBlurConfigurationQualityPrioritizationNormal = 1,
    VTMotionBlurConfigurationQualityPrioritizationQuality = 2,
} NS_SWIFT_NAME(VTMotionBlurQualityPrioritization);

typedef NS_ENUM(NSInteger, VTMotionBlurConfigurationRevision) {
    VTMotionBlurConfigurationRevision1 = 1,
} NS_SWIFT_NAME(VTMotionBlurRevision);

typedef NS_ENUM(NSInteger, VTMotionBlurParametersSubmissionMode) {
    VTMotionBlurParametersSubmissionModeRandom = 1,
    VTMotionBlurParametersSubmissionModeSequential = 2,
} NS_SWIFT_NAME(VTMotionBlurSubmissionMode);

typedef NS_ENUM(NSInteger, VTOpticalFlowConfigurationQualityPrioritization) {
    VTOpticalFlowConfigurationQualityPrioritizationNormal = 1,
    VTOpticalFlowConfigurationQualityPrioritizationQuality = 2,
} NS_SWIFT_NAME(VTOpticalFlowQualityPrioritization);

typedef NS_ENUM(NSInteger, VTOpticalFlowConfigurationRevision) {
    VTOpticalFlowConfigurationRevision1 = 1,
} NS_SWIFT_NAME(VTOpticalFlowRevision);

typedef NS_ENUM(NSInteger, VTOpticalFlowParametersSubmissionMode) {
    VTOpticalFlowParametersSubmissionModeRandom = 1,
    VTOpticalFlowParametersSubmissionModeSequential = 2,
} NS_SWIFT_NAME(VTOpticalFlowSubmissionMode);

typedef NS_ENUM(NSInteger, VTSuperResolutionScalerConfigurationInputType) {
    VTSuperResolutionScalerConfigurationInputTypeVideo = 1,
    VTSuperResolutionScalerConfigurationInputTypeImage = 2,
} NS_SWIFT_NAME(VTSuperResolutionScalerInputType);

typedef NS_ENUM(NSInteger, VTSuperResolutionScalerConfigurationModelStatus) {
    VTSuperResolutionScalerConfigurationModelStatusDownloadRequired = 0,
    VTSuperResolutionScalerConfigurationModelStatusDownloading = 1,
    VTSuperResolutionScalerConfigurationModelStatusReady = 2,
} NS_SWIFT_NAME(VTSuperResolutionScalerModelStatus);

typedef NS_ENUM(NSInteger, VTSuperResolutionScalerConfigurationQualityPrioritization) {
    VTSuperResolutionScalerConfigurationQualityPrioritizationNormal = 1,
} NS_SWIFT_NAME(VTSuperResolutionScalerQualityPrioritization);

typedef NS_ENUM(NSInteger, VTSuperResolutionScalerConfigurationRevision) {
    VTSuperResolutionScalerConfigurationRevision1 = 1,
} NS_SWIFT_NAME(VTSuperResolutionScalerRevision);

typedef NS_ENUM(NSInteger, VTSuperResolutionScalerParametersSubmissionMode) {
    VTSuperResolutionScalerParametersSubmissionModeRandom = 1,
    VTSuperResolutionScalerParametersSubmissionModeSequential = 2,
} NS_SWIFT_NAME(VTSuperResolutionScalerSubmissionMode);

@protocol VTFrameProcessorConfiguration <NSObject>

@property (class, nonatomic, readonly, getter=isSupported) BOOL supported;
@property (nonatomic, readonly, strong, nullable) NSArray<NSNumber *> *frameSupportedPixelFormats;
@property (nonatomic, readonly, strong, nullable) NSDictionary<NSString *, id> *sourcePixelBufferAttributes;
@property (nonatomic, readonly, strong, nullable) NSDictionary<NSString *, id> *destinationPixelBufferAttributes;
@property (nonatomic, readonly, assign) NSInteger nextFrameCount;
@property (nonatomic, readonly, assign) NSInteger previousFrameCount;
@property (class, nonatomic, readonly) CMVideoDimensions maximumDimensions;
@property (class, nonatomic, readonly) CMVideoDimensions minimumDimensions;

@end

@protocol VTFrameProcessorParameters <NSObject>

@property (nonatomic, readonly, strong, nullable) VTFrameProcessorFrame *sourceFrame;
@property (nonatomic, readonly, strong, nullable) VTFrameProcessorFrame *destinationFrame;
@property (nonatomic, readonly, strong, nullable) NSArray<VTFrameProcessorFrame *> *destinationFrames;

@end

// The motion blur configuration, the first of the seventeen: what the application asks of the processor
// for one direction, and what the system would answer it with. Every property is a value the caller
// set or the system read, and the store keeps it under the property's own name.
@interface VTMotionBlurConfiguration : NSObject <VTFrameProcessorConfiguration>

@property (nonatomic, readonly, assign) NSInteger frameWidth;
@property (nonatomic, readonly, assign) NSInteger frameHeight;
@property (nonatomic, readonly, assign) BOOL usePrecomputedFlow;
@property (nonatomic, readonly, assign) VTMotionBlurConfigurationQualityPrioritization qualityPrioritization;
@property (nonatomic, readonly, assign) VTMotionBlurConfigurationRevision revision;
@property (class, nonatomic, readonly, strong, nullable) NSIndexSet *supportedRevisions;
@property (class, nonatomic, readonly, assign) VTMotionBlurConfigurationRevision defaultRevision;
// -processorSupported is NOT declared here on purpose: the SDK declares it
// API_DEPCRECATED_WITH_REPLACEMENT("isSupported", macos(15.4, 26.0)) API_UNAVAILABLE(ios), so on iOS
// the property does not exist and carrying it would collide with the host's own header. The ledger has a
// row for it and registry/VideoToolbox/ios26.json records it as absent for that measured reason.

- (nullable instancetype)initWithFrameWidth:(NSInteger)frameWidth
                                 frameHeight:(NSInteger)frameHeight
                       usePrecomputedFlow:(BOOL)usePrecomputedFlow
                    qualityPrioritization:(VTMotionBlurConfigurationQualityPrioritization)qualityPrioritization
                                   revision:(VTMotionBlurConfigurationRevision)revision;

@end

@interface VTSuperResolutionScalerConfiguration : NSObject <VTFrameProcessorConfiguration>


@property (class, nonatomic, readonly, assign, getter=isSupported) BOOL supported;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> * frameSupportedPixelFormats;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * sourcePixelBufferAttributes;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * destinationPixelBufferAttributes;
@property (nonatomic, readonly, assign) NSInteger nextFrameCount;
@property (nonatomic, readonly, assign) NSInteger previousFrameCount;
@property (class, nonatomic, readonly, assign) CMVideoDimensions maximumDimensions;
@property (class, nonatomic, readonly, assign) CMVideoDimensions minimumDimensions;

@property (nonatomic, readonly, assign) NSInteger frameWidth;
@property (nonatomic, readonly, assign) NSInteger frameHeight;
@property (nonatomic, readonly, assign) VTSuperResolutionScalerConfigurationInputType inputType;
@property (nonatomic, readonly, assign, getter=usesPrecomputedFlow) BOOL precomputedFlow;
@property (nonatomic, readonly, assign) NSInteger scaleFactor;
@property (nonatomic, readonly, assign) VTSuperResolutionScalerConfigurationQualityPrioritization qualityPrioritization;
@property (nonatomic, readonly, assign) VTSuperResolutionScalerConfigurationRevision revision;
@property (class, nonatomic, readonly, strong) NSIndexSet * supportedRevisions;
@property (class, nonatomic, readonly, assign) VTSuperResolutionScalerConfigurationRevision defaultRevision;
@property (nonatomic, readonly, assign) VTSuperResolutionScalerConfigurationModelStatus configurationModelStatus;
@property (nonatomic, readonly, assign) float configurationModelPercentageAvailable;
@property (class, nonatomic, readonly, strong) NSArray<NSNumber*> * supportedScaleFactors;

- (void)downloadConfigurationModelWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;

- (nullable instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        scaleFactor:(NSInteger)scaleFactor
                        inputType:(VTSuperResolutionScalerConfigurationInputType)inputType
                        usePrecomputedFlow:(BOOL)usePrecomputedFlow
                        qualityPrioritization:(VTSuperResolutionScalerConfigurationQualityPrioritization)qualityPrioritization
                        revision:(VTSuperResolutionScalerConfigurationRevision)revision;
@end

@interface VTFrameRateConversionConfiguration : NSObject <VTFrameProcessorConfiguration>


@property (class, nonatomic, readonly, assign, getter=isSupported) BOOL supported;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> * frameSupportedPixelFormats;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * sourcePixelBufferAttributes;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * destinationPixelBufferAttributes;
@property (nonatomic, readonly, assign) NSInteger nextFrameCount;
@property (nonatomic, readonly, assign) NSInteger previousFrameCount;
@property (class, nonatomic, readonly, assign) CMVideoDimensions maximumDimensions;
@property (class, nonatomic, readonly, assign) CMVideoDimensions minimumDimensions;

@property (nonatomic, readonly, assign) NSInteger frameWidth;
@property (nonatomic, readonly, assign) NSInteger frameHeight;
@property (nonatomic, readonly, assign) BOOL usePrecomputedFlow;
@property (nonatomic, readonly, assign) VTFrameRateConversionConfigurationQualityPrioritization qualityPrioritization;
@property (nonatomic, readonly, assign) VTFrameRateConversionConfigurationRevision revision;
@property (class, nonatomic, readonly, strong) NSIndexSet * supportedRevisions;
@property (class, nonatomic, readonly, assign) VTFrameRateConversionConfigurationRevision defaultRevision;

- (nullable instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        usePrecomputedFlow:(BOOL)usePrecomputedFlow
                        qualityPrioritization:(VTFrameRateConversionConfigurationQualityPrioritization)qualityPrioritization
                        revision:(VTFrameRateConversionConfigurationRevision)revision;
@end

@interface VTTemporalNoiseFilterConfiguration : NSObject <VTFrameProcessorConfiguration>


@property (class, nonatomic, readonly, assign, getter=isSupported) BOOL supported;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> * frameSupportedPixelFormats;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * sourcePixelBufferAttributes;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * destinationPixelBufferAttributes;
@property (nonatomic, readonly, assign) NSInteger nextFrameCount;
@property (nonatomic, readonly, assign) NSInteger previousFrameCount;
@property (class, nonatomic, readonly, assign) CMVideoDimensions maximumDimensions;
@property (class, nonatomic, readonly, assign) CMVideoDimensions minimumDimensions;

@property (nonatomic, readonly, assign) NSInteger frameWidth;
@property (nonatomic, readonly, assign) NSInteger frameHeight;
@property (class, nonatomic, readonly, strong) NSArray<NSNumber *> * supportedSourcePixelFormats;

- (nullable instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        sourcePixelFormat:(OSType)sourcePixelFormat;
@end

@interface VTMotionBlurParameters : NSObject <VTFrameProcessorParameters>


@property (nonatomic, readonly, strong) VTFrameProcessorFrame * sourceFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * destinationFrame;
@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * destinationFrames;

@property (nonatomic, readonly, strong) VTFrameProcessorFrame * nextFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * previousFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorOpticalFlow * nextOpticalFlow;
@property (nonatomic, readonly, strong) VTFrameProcessorOpticalFlow * previousOpticalFlow;
@property (nonatomic, readonly, assign) NSInteger motionBlurStrength;
@property (nonatomic, readonly, assign) VTMotionBlurParametersSubmissionMode submissionMode;

- (nullable instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrame:(VTFrameProcessorFrame * _Nullable)nextFrame
                        previousFrame:(VTFrameProcessorFrame * _Nullable)previousFrame
                        nextOpticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)nextOpticalFlow
                        previousOpticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)previousOpticalFlow
                        motionBlurStrength:(NSInteger)motionBlurStrength
                        submissionMode:(VTMotionBlurParametersSubmissionMode)submissionMode
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame;
@end

@interface VTOpticalFlowConfiguration : NSObject <VTFrameProcessorConfiguration>


@property (class, nonatomic, readonly, assign, getter=isSupported) BOOL supported;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> * frameSupportedPixelFormats;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * sourcePixelBufferAttributes;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * destinationPixelBufferAttributes;
@property (nonatomic, readonly, assign) NSInteger nextFrameCount;
@property (nonatomic, readonly, assign) NSInteger previousFrameCount;
@property (class, nonatomic, readonly, assign) CMVideoDimensions maximumDimensions;
@property (class, nonatomic, readonly, assign) CMVideoDimensions minimumDimensions;

@property (nonatomic, readonly, assign) NSInteger frameWidth;
@property (nonatomic, readonly, assign) NSInteger frameHeight;
@property (nonatomic, readonly, assign) VTOpticalFlowConfigurationQualityPrioritization qualityPrioritization;
@property (nonatomic, readonly, assign) VTOpticalFlowConfigurationRevision revision;
@property (class, nonatomic, readonly, strong) NSIndexSet * supportedRevisions;
@property (class, nonatomic, readonly, assign) VTOpticalFlowConfigurationRevision defaultRevision;

- (nullable instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        qualityPrioritization:(VTOpticalFlowConfigurationQualityPrioritization)qualityPrioritization
                        revision:(VTOpticalFlowConfigurationRevision)revision;
@end

@interface VTSuperResolutionScalerParameters : NSObject <VTFrameProcessorParameters>


@property (nonatomic, readonly, strong) VTFrameProcessorFrame * sourceFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * destinationFrame;
@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * destinationFrames;

@property (nonatomic, readonly, strong) VTFrameProcessorFrame * previousFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * previousOutputFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorOpticalFlow * opticalFlow;
@property (nonatomic, readonly, assign) VTSuperResolutionScalerParametersSubmissionMode submissionMode;

- (nullable instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        previousFrame:(VTFrameProcessorFrame * _Nullable)previousFrame
                        previousOutputFrame:(VTFrameProcessorFrame * _Nullable)previousOutputFrame
                        opticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)opticalFlow
                        submissionMode:(VTSuperResolutionScalerParametersSubmissionMode)submissionMode
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame;
@end

@interface VTFrameProcessor : NSObject

- (BOOL)startSessionWithConfiguration:(id<VTFrameProcessorConfiguration>)configuration
                                 error:(NSError * _Nullable * _Nullable)error;

- (BOOL)processWithParameters:(id<VTFrameProcessorParameters>)parameters
                        error:(NSError * _Nullable * _Nullable)error;

- (void)processWithParameters:(id<VTFrameProcessorParameters>)parameters
            completionHandler:(void (^)(id<VTFrameProcessorParameters>, NSError * _Nullable))completionHandler;

- (void)processWithParameters:(id<VTFrameProcessorParameters>)parameters
           frameOutputHandler:(void (^)(id<VTFrameProcessorParameters>, CMTime, BOOL, NSError * _Nullable))frameOutputHandler;

- (void)processWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                       parameters:(id<VTFrameProcessorParameters>)parameters;

- (void)endSession;

@end

@interface VTFrameRateConversionParameters : NSObject <VTFrameProcessorParameters>


@property (nonatomic, readonly, strong) VTFrameProcessorFrame * sourceFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * destinationFrame;
@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * destinationFrames;

@property (nonatomic, readonly, strong) VTFrameProcessorFrame * nextFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorOpticalFlow * opticalFlow;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> * interpolationPhase;
@property (nonatomic, readonly, assign) VTFrameRateConversionParametersSubmissionMode submissionMode;

- (nullable instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrame:(VTFrameProcessorFrame *)nextFrame
                        opticalFlow:(VTFrameProcessorOpticalFlow * _Nullable)opticalFlow
                        interpolationPhase:(NSArray<NSNumber *> *)interpolationPhase
                        submissionMode:(VTFrameRateConversionParametersSubmissionMode)submissionMode
                        destinationFrames:(NSArray<VTFrameProcessorFrame *> *)destinationFrame;
@end

@interface VTLowLatencyFrameInterpolationConfiguration : NSObject <VTFrameProcessorConfiguration>


@property (class, nonatomic, readonly, assign, getter=isSupported) BOOL supported;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> * frameSupportedPixelFormats;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * sourcePixelBufferAttributes;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * destinationPixelBufferAttributes;
@property (nonatomic, readonly, assign) NSInteger nextFrameCount;
@property (nonatomic, readonly, assign) NSInteger previousFrameCount;
@property (class, nonatomic, readonly, assign) CMVideoDimensions maximumDimensions;
@property (class, nonatomic, readonly, assign) CMVideoDimensions minimumDimensions;

@property (nonatomic, readonly, assign) NSInteger frameWidth;
@property (nonatomic, readonly, assign) NSInteger frameHeight;
@property (nonatomic, readonly, assign) NSInteger spatialScaleFactor;
@property (nonatomic, readonly, assign) NSInteger numberOfInterpolatedFrames;

- (nullable instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        numberOfInterpolatedFrames:(NSInteger)numberOfInterpolatedFrames;
- (nullable instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        spatialScaleFactor:(NSInteger)spatialScaleFactor;
@end

@interface VTTemporalNoiseFilterParameters : NSObject <VTFrameProcessorParameters>


@property (nonatomic, readonly, strong) VTFrameProcessorFrame * sourceFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * destinationFrame;
@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * destinationFrames;

@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * nextFrames;
@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * previousFrames;
@property (nonatomic, readonly, assign) float filterStrength;
@property (nonatomic, readonly, assign) BOOL hasDiscontinuity;

- (nullable instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrames:(NSArray<VTFrameProcessorFrame *> *)nextFrames
                        previousFrames:(NSArray<VTFrameProcessorFrame *> *)previousFrames
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame
                        filterStrength:(float)filterStrength
                        hasDiscontinuity:(Boolean)hasDiscontinuity;
@end

@interface VTLowLatencySuperResolutionScalerParameters : NSObject <VTFrameProcessorParameters>


@property (nonatomic, readonly, strong) VTFrameProcessorFrame * sourceFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * destinationFrame;
@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * destinationFrames;

- (nullable instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        destinationFrame:(VTFrameProcessorFrame *)destinationFrame;
@end

@interface VTFrameProcessorFrame : NSObject


@property (nonatomic, readonly, assign) CVPixelBufferRef buffer;
@property (nonatomic, readonly, assign) CMTime presentationTimeStamp;

- (nullable instancetype)initWithBuffer:(CVPixelBufferRef)buffer
                        presentationTimeStamp:(CMTime)presentationTimeStamp;
@end

@interface VTOpticalFlowParameters : NSObject <VTFrameProcessorParameters>


@property (nonatomic, readonly, strong) VTFrameProcessorFrame * sourceFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * destinationFrame;
@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * destinationFrames;

@property (nonatomic, readonly, strong) VTFrameProcessorFrame * nextFrame;
@property (nonatomic, readonly, assign) VTOpticalFlowParametersSubmissionMode submissionMode;
@property (nonatomic, readonly, strong) VTFrameProcessorOpticalFlow * destinationOpticalFlow;

- (nullable instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        nextFrame:(VTFrameProcessorFrame *)nextFrame
                        submissionMode:(VTOpticalFlowParametersSubmissionMode)submissionMode
                        destinationOpticalFlow:(VTFrameProcessorOpticalFlow *)destinationOpticalFlow;
@end

@interface VTLowLatencyFrameInterpolationParameters : NSObject <VTFrameProcessorParameters>


@property (nonatomic, readonly, strong) VTFrameProcessorFrame * sourceFrame;
@property (nonatomic, readonly, strong) VTFrameProcessorFrame * destinationFrame;
@property (nonatomic, readonly, strong) NSArray<VTFrameProcessorFrame *> * destinationFrames;

@property (nonatomic, readonly, strong) VTFrameProcessorFrame * previousFrame;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> * interpolationPhase;

- (nullable instancetype)initWithSourceFrame:(VTFrameProcessorFrame *)sourceFrame
                        previousFrame:(VTFrameProcessorFrame *)previousFrame
                        interpolationPhase:(NSArray<NSNumber *> *)interpolationPhase
                        destinationFrames:(NSArray<VTFrameProcessorFrame *> *)destinationFrames;
@end

@interface VTFrameProcessorOpticalFlow : NSObject


@property (nonatomic, readonly, assign) CVPixelBufferRef forwardFlow;
@property (nonatomic, readonly, assign) CVPixelBufferRef backwardFlow;

- (nullable instancetype)initWithForwardFlow:(CVPixelBufferRef)forwardFlow
                        backwardFlow:(CVPixelBufferRef)backwardFlow;
@end

@interface VTLowLatencySuperResolutionScalerConfiguration : NSObject <VTFrameProcessorConfiguration>


@property (class, nonatomic, readonly, assign, getter=isSupported) BOOL supported;
@property (nonatomic, readonly, strong) NSArray<NSNumber *> * frameSupportedPixelFormats;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * sourcePixelBufferAttributes;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, id> * destinationPixelBufferAttributes;
@property (nonatomic, readonly, assign) NSInteger nextFrameCount;
@property (nonatomic, readonly, assign) NSInteger previousFrameCount;
@property (class, nonatomic, readonly, assign) CMVideoDimensions maximumDimensions;
@property (class, nonatomic, readonly, assign) CMVideoDimensions minimumDimensions;

@property (nonatomic, readonly, assign) NSInteger frameWidth;
@property (nonatomic, readonly, assign) NSInteger frameHeight;
@property (nonatomic, readonly, assign) float scaleFactor;

+ (NSArray<NSNumber *> *)supportedScaleFactorsForFrameWidth:(NSInteger)frameWidth
                                                 frameHeight:(NSInteger)frameHeight;

- (nullable instancetype)initWithFrameWidth:(NSInteger)frameWidth
                        frameHeight:(NSInteger)frameHeight
                        scaleFactor:(float)scaleFactor;
@end

#endif // CHARON_HOST_DIFFERENTIAL

NS_ASSUME_NONNULL_END

#endif
