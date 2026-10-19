#import <CoreMedia/CoreMedia.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

OSStatus CharonHostCMSampleBufferCopyPCMDataIntoAudioBufferList(CMSampleBufferRef sbuf, int32_t frameOffset, int32_t numFrames, AudioBufferList *bufferList);

static int failures, checks, cornerSame, cornerDifferent;

// The claim (registry/CoreMedia/ios7.json, facts/CoreMedia/CMSampleBufferCopyPCMDataIntoAudioBufferList.md):
// for a destination list with as many buffers as the sample buffer's own, and an offset and a frame count
// that are not negative, the port answers the host's own status and writes the host's own bytes. Outside it the host
// answers from the shape it was handed in a way the port does not reproduce; how often the two still agree
// is measured and printed rather than asserted.
static int insideClaim(CMSampleBufferRef buffer, int32_t offset, int32_t frames, UInt32 buffers, CMBlockBufferRef probe)
{
    (void)probe;
    if (frames < 0 || offset < 0)
        return 0;
    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(buffer);
    const AudioStreamBasicDescription *stream = format ? CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)format) : NULL;
    if (!stream)
        return 0;
    // For non-interleaved audio with more than one channel the host reads past the end of the buffer it
    // was handed (facts/CoreMedia/CMSampleBufferCopyPCMDataIntoAudioBufferList.md), so that shape is
    // outside the claim and its agreement is measured instead.
    if ((stream->mFormatFlags & kAudioFormatFlagIsNonInterleaved) && stream->mChannelsPerFrame > 1)
        return 0;
    size_t needed = 0;
    if (CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer, &needed, NULL, 0, NULL, NULL, 0, NULL))
        return 0;
    AudioBufferList *source = needed ? calloc(1, needed) : NULL;
    CMBlockBufferRef held = NULL;
    OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer, NULL, source, needed, NULL, NULL, 0, &held);
    UInt32 count = status == 0 ? source->mNumberBuffers : 0;
    if (held)
        CFRelease(held);
    free(source);
    return buffers == count;
}

// An AudioBufferList holds one AudioBuffer inline, so a list of n buffers is a block of
// sizeof(AudioBufferList) + (n - 1) * sizeof(AudioBuffer) read through the struct's own type.
static AudioBufferList *listOf(UInt32 buffers, size_t bytes, UInt32 numberChannels)
{
    size_t slots = buffers ? buffers : 1;
    AudioBufferList *list = calloc(1, sizeof(AudioBufferList) + (slots - 1) * sizeof(AudioBuffer));
    list->mNumberBuffers = buffers;
    for (UInt32 index = 0; index < buffers; index++) {
        list->mBuffers[index].mNumberChannels = numberChannels;
        list->mBuffers[index].mDataByteSize = (UInt32)bytes;
        list->mBuffers[index].mData = calloc(bytes ? bytes : 1, 1);
    }
    return list;
}

static void releaseList(AudioBufferList *list)
{
    for (UInt32 index = 0; index < list->mNumberBuffers; index++)
        free(list->mBuffers[index].mData);
    free(list);
}

static NSString *hex(const void *bytes, size_t length)
{
    const unsigned char *values = bytes;
    NSMutableString *out = [NSMutableString string];
    for (size_t index = 0; index < length; index++)
        [out appendFormat:@"%02x", values[index]];
    return out;
}

static void compare(const char *name, CMSampleBufferRef buffer, int32_t offset, int32_t frames, AudioBufferList *shape)
{
    char label[256];
    snprintf(label, sizeof label, "%s dst %u buffers", name, shape->mNumberBuffers);
    for (UInt32 index = 0; index < shape->mNumberBuffers; index++)
        snprintf(label + strlen(label), sizeof label - strlen(label), " %u/nc%u", shape->mBuffers[index].mDataByteSize, shape->mBuffers[index].mNumberChannels);
    name = label;
    AudioBufferList *system = listOf(shape->mNumberBuffers, shape->mBuffers[0].mDataByteSize, shape->mBuffers[0].mNumberChannels);
    AudioBufferList *port = listOf(shape->mNumberBuffers, shape->mBuffers[0].mDataByteSize, shape->mBuffers[0].mNumberChannels);
    for (UInt32 index = 1; index < shape->mNumberBuffers; index++) {
        system->mBuffers[index].mDataByteSize = shape->mBuffers[index].mDataByteSize;
        port->mBuffers[index].mDataByteSize = shape->mBuffers[index].mDataByteSize;
        system->mBuffers[index].mNumberChannels = shape->mBuffers[index].mNumberChannels;
        port->mBuffers[index].mNumberChannels = shape->mBuffers[index].mNumberChannels;
    }
    OSStatus a = CMSampleBufferCopyPCMDataIntoAudioBufferList(buffer, offset, frames, system);
    OSStatus b = CharonHostCMSampleBufferCopyPCMDataIntoAudioBufferList(buffer, offset, frames, port);
    int claimed = buffer && insideClaim(buffer, offset, frames, shape->mNumberBuffers, NULL);
    if (!claimed) {
        cornerSame += a == b;
        cornerDifferent += a != b;
        goto done;
    }
    checks++;
    if (a != b) {
        failures++;
        if (failures < 30)
            printf("DIFFERENT %s offset %d frames %d: status %d vs %d\n", name, offset, frames, a, b);
    } else {
        for (UInt32 index = 0; index < shape->mNumberBuffers; index++) {
            size_t length = shape->mBuffers[index].mDataByteSize;
            if (memcmp(system->mBuffers[index].mData, port->mBuffers[index].mData, length) != 0) {
                failures++;
                if (failures < 30)
                    printf("DIFFERENT %s offset %d frames %d buffer %u: %s vs %s\n", name, offset, frames, index,
                           hex(system->mBuffers[index].mData, length).UTF8String, hex(port->mBuffers[index].mData, length).UTF8String);
                break;
            }
        }
    }
done:
    releaseList(system);
    releaseList(port);
}

static CMSampleBufferRef make(AudioStreamBasicDescription *stream, size_t frames, Boolean ready)
{
    size_t frameBytes = (stream->mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? stream->mBytesPerFrame : stream->mBytesPerFrame / stream->mChannelsPerFrame;
    size_t total = frames * frameBytes * stream->mChannelsPerFrame;
    size_t backing = total ? total : 1;
    uint8_t *bytes = calloc(backing, 1);
    for (size_t index = 0; index < backing; index++)
        bytes[index] = (uint8_t)(index + 1);
    CMBlockBufferRef block = NULL;
    if (CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, backing, kCFAllocatorDefault, NULL, 0, backing, kCMBlockBufferAssureMemoryNowFlag, &block)) {
        free(bytes);
        return NULL;
    }
    CMBlockBufferReplaceDataBytes(bytes, block, 0, backing);
    free(bytes);
    CMAudioFormatDescriptionRef format = NULL;
    if (CMAudioFormatDescriptionCreate(kCFAllocatorDefault, stream, 0, NULL, 0, NULL, NULL, &format)) {
        CFRelease(block);
        return NULL;
    }
    CMSampleTimingInfo timing = {CMTimeMake((int64_t)frames, stream->mSampleRate), kCMTimeZero, kCMTimeInvalid};
    CMSampleBufferRef buffer = NULL;
    CMSampleBufferCreate(kCFAllocatorDefault, block, ready, NULL, NULL, format, frames, 1, &timing, 1, &total, &buffer);
    CFRelease(block);
    CFRelease(format);
    return buffer;
}

int main(void)
{
    @autoreleasepool {
        static const UInt32 formats[] = {kAudioFormatLinearPCM, kAudioFormatMPEG4AAC, kAudioFormatAppleLossless, kAudioFormatULaw};
        static const UInt32 flags[] = {0, kAudioFormatFlagIsNonInterleaved};
        static const UInt32 channels[] = {1, 2, 3};
        static const size_t frameCounts[] = {1, 2, 5, 16};
        static const int32_t offsets[] = {0, 1, 2, 3, 4, 5, 16, -1, -100};
        static const int32_t requests[] = {0, 1, 2, 3, 4, 5, 16, 17, -1};
        for (size_t f = 0; f < sizeof formats / sizeof *formats; f++)
            for (size_t g = 0; g < sizeof flags / sizeof *flags; g++)
                for (size_t c = 0; c < sizeof channels / sizeof *channels; c++)
                    for (size_t n = 0; n < sizeof frameCounts / sizeof *frameCounts; n++) {
                        AudioStreamBasicDescription stream = {0};
                        stream.mSampleRate = 48000;
                        stream.mFormatID = formats[f];
                        stream.mFormatFlags = flags[g];
                        stream.mChannelsPerFrame = channels[c];
                        stream.mBitsPerChannel = 16;
                        stream.mBytesPerFrame = channels[c] * 2;
                        stream.mBytesPerPacket = stream.mBytesPerFrame;
                        stream.mFramesPerPacket = 1;
                        if (formats[f] == kAudioFormatMPEG4AAC) {
                            stream.mBytesPerFrame = 0;
                            stream.mBytesPerPacket = 0;
                            stream.mFramesPerPacket = 1024;
                        }
                        CMSampleBufferRef buffer = make(&stream, frameCounts[n], true);
                        if (!buffer) {
                            printf("could not build a sample buffer for format %u channels %u\n", formats[f], channels[c]);
                            continue;
                        }
                        char name[128];
                        snprintf(name, sizeof name, "format %u flags %u channels %u frames %zu", formats[f], flags[g], channels[c], frameCounts[n]);
                        size_t frameBytes = (flags[g] & kAudioFormatFlagIsNonInterleaved) ? 2 : 2;
                        size_t bufferBytes = frameCounts[n] * frameBytes;
                        for (size_t o = 0; o < sizeof offsets / sizeof *offsets; o++)
                            for (size_t q = 0; q < sizeof requests / sizeof *requests; q++) {
                                for (UInt32 count = 0; count < 4; count++) {
                                    AudioBufferList *shape = listOf(count, bufferBytes, 1);
                                    for (UInt32 index = 0; index < count; index++)
                                        shape->mBuffers[index].mDataByteSize = (UInt32)bufferBytes;
                                    compare(name, buffer, offsets[o], requests[q], shape);
                                    releaseList(shape);
                                }
                                for (size_t bytes = 1; bytes <= bufferBytes * 2; bytes *= 2) {
                                    AudioBufferList *shape = listOf(1, bytes, 1);
                                    compare(name, buffer, offsets[o], requests[q], shape);
                                    releaseList(shape);
                                }
                                for (UInt32 nc = 0; nc <= 2; nc++) {
                                    AudioBufferList *shape = listOf(1, bufferBytes, nc);
                                    compare(name, buffer, offsets[o], requests[q], shape);
                                    releaseList(shape);
                                }
                            }
                        {
                            AudioBufferList *shape = listOf(1, bufferBytes, 1);
                            free(shape->mBuffers[0].mData);
                            shape->mBuffers[0].mData = NULL;
                            OSStatus a = CMSampleBufferCopyPCMDataIntoAudioBufferList(buffer, 0, (int32_t)frameCounts[n], shape);
                            OSStatus b = CharonHostCMSampleBufferCopyPCMDataIntoAudioBufferList(buffer, 0, (int32_t)frameCounts[n], shape);
                            checks++;
                            if (a != b) {
                                failures++;
                                if (failures < 30)
                                    printf("DIFFERENT %s with a null destination: status %d vs %d\n", name, a, b);
                            }
                            releaseList(shape);
                        }
                        CFRelease(buffer);
                        CMSampleBufferRef pending = make(&stream, frameCounts[n], false);
                        if (pending) {
                            AudioBufferList *shape = listOf(1, bufferBytes, 1);
                            compare((const char *)[[NSString stringWithFormat:@"%s not ready", name] UTF8String], pending, 0, (int32_t)frameCounts[n], shape);
                            releaseList(shape);
                            CMSampleBufferInvalidate(pending);
                            compare((const char *)[[NSString stringWithFormat:@"%s invalidated", name] UTF8String], pending, 0, (int32_t)frameCounts[n], shape = listOf(1, bufferBytes, 1));
                            releaseList(shape);
                            CFRelease(pending);
                        }
                    }
        CMVideoFormatDescriptionRef videoFormat = NULL;
        CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_H264, 16, 16, NULL, &videoFormat);
        CMBlockBufferRef block = NULL;
        CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, 64, kCFAllocatorDefault, NULL, 0, 64, kCMBlockBufferAssureMemoryNowFlag, &block);
        CMSampleTimingInfo timing = {CMTimeMake(1, 30), kCMTimeZero, kCMTimeInvalid};
        size_t size = 64;
        CMSampleBufferRef video = NULL;
        CMSampleBufferCreate(kCFAllocatorDefault, block, true, NULL, NULL, videoFormat, 1, 1, &timing, 1, &size, &video);
        AudioBufferList *shape = listOf(1, 64, 1);
        compare("video", video, 0, 1, shape);
        releaseList(shape);
        compare("no buffer", NULL, 0, 1, shape = listOf(1, 64, 1));
        releaseList(shape);
        if (video)
            CFRelease(video);
        if (videoFormat)
            CFRelease(videoFormat);
        if (block)
            CFRelease(block);
        printf("%d inside the claim, %d different; %d outside it, %d of those the same\n", checks, failures, cornerSame + cornerDifferent, cornerSame);
    }
    return failures != 0;
}
