#ifndef REVENANT_VT_DECOMPRESSION_SESSION_HEVC_H
#define REVENANT_VT_DECOMPRESSION_SESSION_HEVC_H

#import <CoreFoundation/CoreFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>

typedef void (^RevenantVTDecodeOutput)(void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration);

__attribute__((visibility("hidden"))) BOOL RevenantVTSoftwareDecodes(CMFormatDescriptionRef format, CFDictionaryRef specification);
__attribute__((visibility("hidden"))) OSStatus RevenantVTSoftwareSessionCreate(CMVideoFormatDescriptionRef format, CFDictionaryRef destinationAttributes, RevenantVTDecodeOutput output, VTDecompressionSessionRef *sessionOut);
__attribute__((visibility("hidden"))) BOOL RevenantVTSoftwareSessionOwns(VTDecompressionSessionRef session);
__attribute__((visibility("hidden"))) OSStatus RevenantVTSoftwareSessionDecode(VTDecompressionSessionRef session, CMSampleBufferRef sampleBuffer, VTDecodeFrameFlags decodeFlags, void *sourceFrameRefCon, VTDecodeInfoFlags *infoFlagsOut, RevenantVTDecodeOutput output);
__attribute__((visibility("hidden"))) OSStatus RevenantVTSoftwareSessionFinish(VTDecompressionSessionRef session);
__attribute__((visibility("hidden"))) void RevenantVTSoftwareSessionInvalidate(VTDecompressionSessionRef session);
__attribute__((visibility("hidden"))) BOOL RevenantVTSoftwareSessionCanAccept(VTDecompressionSessionRef session, CMFormatDescriptionRef format);
__attribute__((visibility("hidden"))) OSStatus RevenantVTSoftwareSessionSetProperty(VTDecompressionSessionRef session, CFStringRef key, CFTypeRef value);
__attribute__((visibility("hidden"))) OSStatus RevenantVTSoftwareSessionCopyProperty(VTDecompressionSessionRef session, CFStringRef key, CFAllocatorRef allocator, CFTypeRef *valueOut);
__attribute__((visibility("hidden"))) CFDictionaryRef RevenantVTSoftwareSessionCopySupportedProperties(VTDecompressionSessionRef session);

#endif
