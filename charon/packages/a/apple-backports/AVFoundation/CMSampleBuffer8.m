#import <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <CoreAudioTypes/CoreAudioTypes.h>
#include <AudioToolbox/AudioToolbox.h>
#include <stdlib.h>
#include <string.h>

const CFStringRef kCMSampleBufferAttachmentKey_ForceKeyFrame = CFSTR("ForceKeyFrame");
const CFStringRef kCMSampleBufferNotificationParameter_OSStatus = CFSTR("OSStatus");
const CFStringRef kCMSampleBufferNotification_DataFailed = CFSTR("CMSampleBufferDataFailed");

OSStatus CMSampleBufferCreateReady(CFAllocatorRef allocator, CMBlockBufferRef dataBuffer, CMFormatDescriptionRef formatDescription,
                                   CMItemCount numSamples, CMItemCount numSampleTimingEntries, const CMSampleTimingInfo *sampleTimingArray,
                                   CMItemCount numSampleSizeEntries, const size_t *sampleSizeArray, CMSampleBufferRef *sampleBufferOut)
{
    return CMSampleBufferCreate(allocator, dataBuffer, true, NULL, NULL, formatDescription, numSamples, numSampleTimingEntries,
                                sampleTimingArray, numSampleSizeEntries, sampleSizeArray, sampleBufferOut);
}

OSStatus CMSampleBufferCreateReadyWithImageBuffer(CFAllocatorRef allocator, CVImageBufferRef imageBuffer, CMVideoFormatDescriptionRef formatDescription,
                                                  const CMSampleTimingInfo *sampleTiming, CMSampleBufferRef *sampleBufferOut)
{
    return CMSampleBufferCreateForImageBuffer(allocator, imageBuffer, true, NULL, NULL, formatDescription, sampleTiming, sampleBufferOut);
}

OSStatus CMSampleBufferCallBlockForEachSample(CMSampleBufferRef sbuf, OSStatus (^handler)(CMSampleBufferRef sampleBuffer, CMItemCount index))
{
    if (!sbuf || !handler)
        return kCMSampleBufferError_RequiredParameterMissing;
    CMItemCount samples = CMSampleBufferGetNumSamples(sbuf);
    if (!samples)
        return 0;
    size_t *sizes = calloc(samples, sizeof *sizes);
    if (!sizes)
        return kCMSampleBufferError_AllocationFailed;
    CMItemCount got = 0;
    OSStatus status = CMSampleBufferGetSampleSizeArray(sbuf, samples, sizes, &got);
    if (status == kCMSampleBufferError_BufferHasNoSampleSizes || got < samples)
        status = kCMSampleBufferError_CannotSubdivide;
    CMBlockBufferRef data = status ? NULL : CMSampleBufferGetDataBuffer(sbuf);
    size_t offset = 0;
    for (CMItemCount index = 0; status == 0 && index < samples; index++) {
        CMSampleTimingInfo timing;
        status = CMSampleBufferGetSampleTimingInfo(sbuf, index, &timing);
        CMBlockBufferRef piece = NULL;
        CMSampleBufferRef one = NULL;
        if (status == 0)
            status = CMBlockBufferCreateWithBufferReference(kCFAllocatorDefault, data, offset, sizes[index], 0, &piece);
        if (status == 0)
            status = CMSampleBufferCreate(kCFAllocatorDefault, piece, true, NULL, NULL, CMSampleBufferGetFormatDescription(sbuf), 1, 1, &timing, 1, &sizes[index], &one);
        if (status == 0) {
            status = handler(one, index);
            CFRelease(one);
        }
        if (piece)
            CFRelease(piece);
        offset += sizes[index];
    }
    free(sizes);
    return status;
}

OSStatus CMAudioSampleBufferCreateReadyWithPacketDescriptions(CFAllocatorRef allocator, CMBlockBufferRef dataBuffer, CMFormatDescriptionRef formatDescription,
                                                             CMItemCount numSamples, CMTime presentationTimeStamp,
                                                             const AudioStreamPacketDescription *packetDescriptions, CMSampleBufferRef *sampleBufferOut)
{
    if (!sampleBufferOut)
        return kCMSampleBufferError_RequiredParameterMissing;
    *sampleBufferOut = NULL;
    if (!formatDescription)
        return kCMSampleBufferError_RequiredParameterMissing;
    if (!numSamples)
        return kCMSampleBufferError_InvalidEntryCount;
    if (!CMTIME_IS_NUMERIC(presentationTimeStamp))
        return kCMSampleBufferError_SampleTimingInfoInvalid;
    const AudioStreamBasicDescription *stream = CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)formatDescription);
    if (!stream || !stream->mSampleRate)
        return kCMSampleBufferError_InvalidMediaFormat;
    size_t fixedBytes = stream->mBytesPerFrame ? stream->mBytesPerFrame : (size_t)(stream->mBitsPerChannel / 8) * stream->mChannelsPerFrame;
    if (!packetDescriptions && !fixedBytes)
        return kCMSampleBufferError_RequiredParameterMissing;
    // One timing entry and one size entry, the "every sample is the same" form Apple's own header
    // describes: with two packets the host answers one entry of 1024/44100 at the presentation timestamp
    // it was given, and one size (measured over 239 answers).
    size_t *sizes = calloc(1, sizeof *sizes);
    CMSampleTimingInfo *timings = calloc(1, sizeof *timings);
    if (!sizes || !timings) {
        free(sizes);
        free(timings);
        return kCMSampleBufferError_AllocationFailed;
    }
    const AudioStreamPacketDescription *packet = packetDescriptions ? &packetDescriptions[0] : NULL;
    timings[0].duration = CMTimeMake((int32_t)stream->mFramesPerPacket, (int32_t)stream->mSampleRate);
    timings[0].presentationTimeStamp = presentationTimeStamp;
    timings[0].decodeTimeStamp = kCMTimeInvalid;
    size_t size = packet && packet->mDataByteSize ? packet->mDataByteSize : (size_t)stream->mFramesPerPacket * fixedBytes;
    // A format with no per-frame byte size of its own - AAC, whose packets vary - needs no sizing array
    // at all: the host answers no size entry for it and one for a linear stream (measured).
    size_t sizeEntries = size || fixedBytes ? 1 : 0;
    if (sizeEntries)
        sizes[0] = size;
    // Measured against the host over 239 answers: zero samples is kCMSampleBufferError_InvalidEntryCount,
    // a presentation timestamp that is not numeric is kCMSampleBufferError_SampleTimingInfoInvalid, and with
    // no packet descriptions the size of a packet has to come from the stream - a format with no
    // mBytesPerFrame and no bit depth, AAC for one, is kCMSampleBufferError_RequiredParameterMissing.
    OSStatus status = CMSampleBufferCreate(allocator, dataBuffer, true, NULL, NULL, formatDescription, numSamples, 1, timings, sizeEntries,
                                           sizeEntries ? sizes : NULL, sampleBufferOut);
    free(sizes);
    free(timings);
    return status;
}
