#ifndef REVENANT_VIDEOTOOLBOX_H
#define REVENANT_VIDEOTOOLBOX_H

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#ifndef REVENANT_VT_DECLARE_FOR_CASE
#import <VideoToolbox/VideoToolbox.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#ifdef REVENANT_VT_DECLARE_FOR_CASE
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

#if !defined(REVENANT_HOST_DIFFERENTIAL) || defined(REVENANT_VT_DECLARE_FOR_CASE)

@protocol MTLCommandBuffer;

typedef struct OpaqueCMTaggedBufferGroup *CMTaggedBufferGroupRef;

typedef void (*VTDecompressionOutputMultiImageCallback)(
    void * CM_NULLABLE decompressionOutputMultiImageRefCon,
    void * CM_NULLABLE sourceFrameRefCon,
    OSStatus status,
    VTDecodeInfoFlags infoFlags,
    CMTaggedBufferGroupRef CM_NULLABLE taggedBufferGroup,
    CMTime presentationTimeStamp,
    CMTime presentationDuration);

#if defined(__BLOCKS__)
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

@interface VTMotionBlurConfiguration : NSObject <VTFrameProcessorConfiguration>

@property (nonatomic, readonly, assign) NSInteger frameWidth;
@property (nonatomic, readonly, assign) NSInteger frameHeight;
@property (nonatomic, readonly, assign) BOOL usePrecomputedFlow;
@property (nonatomic, readonly, assign) VTMotionBlurConfigurationQualityPrioritization qualityPrioritization;
@property (nonatomic, readonly, assign) VTMotionBlurConfigurationRevision revision;
@property (class, nonatomic, readonly, strong, nullable) NSIndexSet *supportedRevisions;
@property (class, nonatomic, readonly, assign) VTMotionBlurConfigurationRevision defaultRevision;

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

#endif

NS_ASSUME_NONNULL_END

#endif
