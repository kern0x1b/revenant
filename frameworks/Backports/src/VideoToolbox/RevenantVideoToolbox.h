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

#endif

NS_ASSUME_NONNULL_END

#endif
