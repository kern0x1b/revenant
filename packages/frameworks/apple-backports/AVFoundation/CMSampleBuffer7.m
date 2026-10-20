#import <CoreMedia/CoreMedia.h>
#include <AudioToolbox/AudioToolbox.h>
#include <stdlib.h>
#include <string.h>

const CFStringRef kCMSampleBufferAttachmentKey_DroppedFrameReasonInfo = CFSTR("DroppedFrameReasonInfo");
const CFStringRef kCMSampleBufferDroppedFrameReasonInfo_CameraModeSwitch = CFSTR("CameraModeSwitch");

OSStatus CMSampleBufferCopyPCMDataIntoAudioBufferList(CMSampleBufferRef sbuf, int32_t frameOffset, int32_t numFrames, AudioBufferList *bufferList)
{
    if (!sbuf || !bufferList)
        return kCMSampleBufferError_RequiredParameterMissing;
    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sbuf);
    if (!format || CMFormatDescriptionGetMediaType(format) != kCMMediaType_Audio)
        return kCMSampleBufferError_InvalidMediaTypeForOperation;
    const AudioStreamBasicDescription *stream = CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)format);
    if (!stream || stream->mFormatID != kAudioFormatLinearPCM)
        return kCMSampleBufferError_InvalidSampleData;
    if (!CMSampleBufferDataIsReady(sbuf))
        return kCMSampleBufferError_BufferNotReady;
    int32_t frames = (int32_t)CMSampleBufferGetNumSamples(sbuf);
    if (frameOffset >= frames || numFrames > frames - frameOffset)
        return kCMSampleBufferError_SampleIndexOutOfRange;
    size_t total = (size_t)frames;
    size_t needed = 0;
    OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sbuf, &needed, NULL, 0, NULL, NULL, 0, NULL);
    if (status)
        return status;
    AudioBufferList *source = needed ? calloc(1, needed) : NULL;
    if (needed && !source)
        return kCMSampleBufferError_AllocationFailed;
    CMBlockBufferRef block = NULL;
    status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sbuf, NULL, source, needed, NULL, NULL, 0, &block);
    if (status == 0) {
        if (bufferList->mNumberBuffers == source->mNumberBuffers) {
            for (UInt32 index = 0; index < source->mNumberBuffers; index++) {
                const AudioBuffer *from = &source->mBuffers[index];
                AudioBuffer *to = &bufferList->mBuffers[index];
                size_t perFrame = total ? from->mDataByteSize / total : 0;
                size_t wanted = perFrame * (size_t)numFrames;
                if (!from->mData || !to->mData || to->mNumberChannels != from->mNumberChannels ||
                    to->mDataByteSize != (UInt32)wanted) {
                    status = kCMSampleBufferError_RequiredParameterMissing;
                    break;
                }
                status = CMBlockBufferCopyDataBytes(block, perFrame * (size_t)frameOffset, wanted, to->mData);
                if (status)
                    break;
            }
        }
    }
    if (block)
        CFRelease(block);
    free(source);
    return status;
}
