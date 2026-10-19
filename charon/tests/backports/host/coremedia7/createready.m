#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

OSStatus CharonHostCMSampleBufferCreateReady(CFAllocatorRef allocator, CMBlockBufferRef dataBuffer, CMFormatDescriptionRef formatDescription,
                                             CMItemCount numSamples, CMItemCount numSampleTimingEntries, const CMSampleTimingInfo *sampleTimingArray,
                                             CMItemCount numSampleSizeEntries, const size_t *sampleSizeArray, CMSampleBufferRef *sampleBufferOut);
OSStatus CharonHostCMSampleBufferCreateReadyWithImageBuffer(CFAllocatorRef allocator, CVImageBufferRef imageBuffer, CMVideoFormatDescriptionRef formatDescription,
                                                            const CMSampleTimingInfo *sampleTiming, CMSampleBufferRef *sampleBufferOut);
OSStatus CharonHostCMSampleBufferCallBlockForEachSample(CMSampleBufferRef sbuf, OSStatus (^handler)(CMSampleBufferRef sampleBuffer, CMItemCount index));
OSStatus CharonHostCMSampleBufferCreateWithMakeDataReadyHandler(CFAllocatorRef allocator, CMBlockBufferRef dataBuffer, Boolean dataReady,
                                                              CMFormatDescriptionRef formatDescription, CMItemCount numSamples,
                                                              CMItemCount numSampleTimingEntries, const CMSampleTimingInfo *sampleTimingArray,
                                                              CMItemCount numSampleSizeEntries, const size_t *sampleSizeArray,
                                                              CMSampleBufferRef *sampleBufferOut, CMSampleBufferMakeDataReadyHandler handler);
OSStatus CharonHostCMSampleBufferCreateForImageBufferWithMakeDataReadyHandler(CFAllocatorRef allocator, CVImageBufferRef imageBuffer, Boolean dataReady,
                                                                            CMVideoFormatDescriptionRef formatDescription, const CMSampleTimingInfo *sampleTiming,
                                                                            CMSampleBufferRef *sampleBufferOut, CMSampleBufferMakeDataReadyHandler handler);

static int failures, checks, cornerSame, cornerDifferent;

OSStatus CharonHostCMAudioSampleBufferCreateReadyWithPacketDescriptions(CFAllocatorRef allocator, CMBlockBufferRef dataBuffer,
                                                                      CMFormatDescriptionRef formatDescription, CMItemCount numSamples,
                                                                      CMTime presentationTimeStamp,
                                                                      const AudioStreamPacketDescription *packetDescriptions,
                                                                      CMSampleBufferRef *sampleBufferOut);

// The claim (registry/CoreMedia/ios8.json): a sample buffer built with a timing entry for every sample is
// the host's own, byte for byte, and every iteration of CallBlockForEachSample hands the block the same
// per-sample buffer and the same bytes for that sample. The temporary buffer's *total* length is not part
// of it: the host's spans the whole data buffer, the port's is exactly the sample
// (facts/CoreMedia/SampleBufferCreateReady.md). A buffer built with fewer timing entries than samples is outside it - the host
// answers for the first sample and fails for the rest, which the port does not reproduce - and there the
// agreement is measured rather than asserted.
static int insideClaim(CMItemCount samples, CMItemCount timings)
{
    return timings >= samples;
}

// CMAudioSampleBufferCreateReadyWithPacketDescriptions: for a format with no per-frame byte size of its
// own (AAC) and a packet description whose mDataByteSize is zero, the host's sizing array depends on the
// packet count in a way this grid could not pin down - one packet gets a zero size entry, two get none -
// so that shape is outside the claim and its agreement is measured (facts/CoreMedia/SampleBufferCreateReady.md).
static int audioClaim(UInt32 packets, const AudioStreamPacketDescription *descriptions, BOOL perFrameSize)
{
    if (perFrameSize)
        return YES;
    if (!descriptions)
        return NO;
    for (UInt32 index = 0; index < packets; index++)
        if (!descriptions[index].mDataByteSize)
            return NO;
    return YES;
}

static NSString *describe(CMSampleBufferRef buffer, int perSample)
{
    if (!buffer)
        return @"none";
    CMItemCount samples = CMSampleBufferGetNumSamples(buffer);
    NSMutableString *out = [NSMutableString stringWithFormat:@"%lu samples ready %d", (unsigned long)samples, CMSampleBufferDataIsReady(buffer)];
    CMItemCount needed = 0;
    if (CMSampleBufferGetSampleTimingInfoArray(buffer, 0, NULL, &needed) == 0) {
        CMSampleTimingInfo *timings = calloc(needed ? needed : 1, sizeof *timings);
        if (CMSampleBufferGetSampleTimingInfoArray(buffer, needed, timings, NULL) == 0)
            for (size_t index = 0; index < needed; index++)
                [out appendFormat:@" [%lld/%d pts %lld/%d dts %lld/%d]", (long long)timings[index].duration.value, timings[index].duration.timescale,
                 (long long)timings[index].presentationTimeStamp.value, timings[index].presentationTimeStamp.timescale,
                 (long long)timings[index].decodeTimeStamp.value, timings[index].decodeTimeStamp.timescale];
        free(timings);
    }
    needed = 0;
    if (CMSampleBufferGetSampleSizeArray(buffer, 0, NULL, &needed) == 0) {
        size_t *sizes = calloc(needed ? needed : 1, sizeof *sizes);
        if (CMSampleBufferGetSampleSizeArray(buffer, needed, sizes, NULL) == 0)
            for (size_t index = 0; index < needed; index++)
                [out appendFormat:@" %zu", sizes[index]];
        free(sizes);
    }
    CMBlockBufferRef data = CMSampleBufferGetDataBuffer(buffer);
    if (data) {
        size_t length = CMBlockBufferGetDataLength(data);
        size_t wanted = length;
        if (perSample) {
            CMItemCount count = 0;
            CMSampleBufferGetSampleSizeArray(buffer, 0, NULL, &count);
            size_t *array = calloc(count ? count : 1, sizeof *array);
            if (!CMSampleBufferGetSampleSizeArray(buffer, count, array, NULL) && count && array[0] < wanted)
                wanted = array[0];
            free(array);
        }
        (void)length;
        [out appendFormat:@" data %zu", wanted];
        uint8_t *bytes = calloc(wanted ? wanted : 1, 1);
        if (CMBlockBufferCopyDataBytes(data, 0, wanted, bytes) == 0) {
            NSMutableString *hex = [NSMutableString string];
            for (size_t index = 0; index < wanted; index++)
                [hex appendFormat:@"%02x", bytes[index]];
            [out appendFormat:@" %@", hex];
        }
        free(bytes);
    }
    return out;
}

static void compare(const char *name, OSStatus a, CMSampleBufferRef system, OSStatus b, CMSampleBufferRef port, int claimed, int needed)
{
    if (!claimed) {
        cornerSame += a == b;
        cornerDifferent += a != b;
        if (system)
            CFRelease(system);
        if (port)
            CFRelease(port);
        return;
    }
    checks++;
    NSString *theirs = describe(system, needed), *mine = describe(port, needed);
    if (a != b || ![theirs isEqualToString:mine]) {
        failures++;
        if (failures < 30)
            printf("DIFFERENT %s: status %d vs %d\n  system %s\n  port   %s\n", name, a, b, theirs.UTF8String, mine.UTF8String);
    }
    if (system)
        CFRelease(system);
    if (port)
        CFRelease(port);
}

static CMBlockBufferRef blockOf(size_t length)
{
    uint8_t *bytes = calloc(length ? length : 1, 1);
    for (size_t index = 0; index < length; index++)
        bytes[index] = (uint8_t)(index * 11 + 5);
    CMBlockBufferRef block = NULL;
    CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, length ? length : 1, kCFAllocatorDefault, NULL, 0, length ? length : 1, kCMBlockBufferAssureMemoryNowFlag, &block);
    CMBlockBufferReplaceDataBytes(bytes, block, 0, length ? length : 1);
    free(bytes);
    return block;
}

int main(void)
{
    @autoreleasepool {
        static const CMItemCount sampleCounts[] = {0, 1, 2, 5};
        static const CMItemCount timingCounts[] = {0, 1, 2, 5, 7};
        CMVideoFormatDescriptionRef format = NULL;
        CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_H264, 16, 16, NULL, &format);
        for (size_t n = 0; n < sizeof sampleCounts / sizeof *sampleCounts; n++)
            for (size_t t = 0; t < sizeof timingCounts / sizeof *timingCounts; t++) {
                size_t length = sampleCounts[n] * 8 + 4;
                CMBlockBufferRef block = blockOf(length);
                size_t *sizes = calloc(sampleCounts[n] ? sampleCounts[n] : 1, sizeof *sizes);
                for (CMItemCount index = 0; index < sampleCounts[n]; index++)
                    sizes[index] = 8;
                CMSampleTimingInfo *timings = calloc(timingCounts[t] ? timingCounts[t] : 1, sizeof *timings);
                for (CMItemCount index = 0; index < timingCounts[t]; index++) {
                    timings[index].duration = CMTimeMake(index + 1, 30);
                    timings[index].presentationTimeStamp = CMTimeMake(index * 100, 30000);
                    timings[index].decodeTimeStamp = kCMTimeInvalid;
                }
                CMSampleBufferRef system = NULL, port = NULL;
                char name[128];
                snprintf(name, sizeof name, "CreateReady %lu samples %lu timings", (unsigned long)sampleCounts[n], (unsigned long)timingCounts[t]);
                compare(name,
                        CMSampleBufferCreateReady(kCFAllocatorDefault, block, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &system),
                        system,
                        CharonHostCMSampleBufferCreateReady(kCFAllocatorDefault, block, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &port),
                        port, 1, 0);
                system = port = NULL;
                snprintf(name, sizeof name, "CreateWithMakeDataReadyHandler %lu samples %lu timings", (unsigned long)sampleCounts[n], (unsigned long)timingCounts[t]);
                __block int ran = 0;
                compare(name,
                        CMSampleBufferCreateWithMakeDataReadyHandler(kCFAllocatorDefault, block, false, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &system,
                                                                     ^OSStatus(CMSampleBufferRef ready) { ran++; return 0; }),
                        system,
                        CharonHostCMSampleBufferCreateWithMakeDataReadyHandler(kCFAllocatorDefault, block, false, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &port,
                                                                                 ^OSStatus(CMSampleBufferRef ready) { ran++; return 0; }),
                        port, 1, 0);
                system = port = NULL;
                snprintf(name, sizeof name, "CreateWithMakeDataReadyHandler already ready %lu samples", (unsigned long)sampleCounts[n]);
                compare(name,
                        CMSampleBufferCreateWithMakeDataReadyHandler(kCFAllocatorDefault, block, true, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &system, nil),
                        system,
                        CharonHostCMSampleBufferCreateWithMakeDataReadyHandler(kCFAllocatorDefault, block, true, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &port, nil),
                        port, 1, 0);
                system = port = NULL;
                snprintf(name, sizeof name, "CreateReady with no data buffer %lu samples", (unsigned long)sampleCounts[n]);
                compare(name,
                        CMSampleBufferCreateReady(kCFAllocatorDefault, NULL, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &system),
                        system,
                        CharonHostCMSampleBufferCreateReady(kCFAllocatorDefault, NULL, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &port),
                        port, 1, 0);
                system = port = NULL;
                snprintf(name, sizeof name, "CreateReady with no out pointer %lu samples", (unsigned long)sampleCounts[n]);
                compare(name, CMSampleBufferCreateReady(kCFAllocatorDefault, block, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, NULL), NULL,
                        CharonHostCMSampleBufferCreateReady(kCFAllocatorDefault, block, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, NULL), NULL, 1, 0);
                free(sizes);
                free(timings);
                CFRelease(block);
            }
        CVPixelBufferRef pixels = NULL;
        CVPixelBufferCreate(kCFAllocatorDefault, 16, 16, kCVPixelFormatType_32BGRA, NULL, &pixels);
        for (size_t t = 0; t < sizeof timingCounts / sizeof *timingCounts; t++) {
            CMSampleTimingInfo timing = {CMTimeMake(1, 30), CMTimeMake(3, 30), kCMTimeInvalid};
            CMSampleBufferRef system = NULL, port = NULL;
            char name[128];
            snprintf(name, sizeof name, "CreateReadyWithImageBuffer timings %lu", (unsigned long)timingCounts[t]);
            (void)t;
            compare(name, CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixels, format, &timing, &system), system,
                    CharonHostCMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixels, format, &timing, &port), port, 1, 0);
            system = port = NULL;
            compare("CreateForImageBufferWithMakeDataReadyHandler",
                    CMSampleBufferCreateForImageBufferWithMakeDataReadyHandler(kCFAllocatorDefault, pixels, false, format, &timing, &system,
                                                                               ^OSStatus(CMSampleBufferRef ready) { return 0; }),
                    system,
                    CharonHostCMSampleBufferCreateForImageBufferWithMakeDataReadyHandler(kCFAllocatorDefault, pixels, false, format, &timing, &port,
                                                                                         ^OSStatus(CMSampleBufferRef ready) { return 0; }),
                    port, 1, 0);
            system = port = NULL;
            compare("CreateReadyWithImageBuffer with no format", CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixels, NULL, &timing, &system), system,
                    CharonHostCMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixels, NULL, &timing, &port), port, 1, 0);
        }
        // CMAudioSampleBufferCreateReadyWithPacketDescriptions: a packet description is a start offset, a
        // frame count and a byte size, and the port lays the sample buffer out from those three.
        {
            static const UInt32 frameCounts[] = {1, 1024, 0};
            static const UInt32 byteSizes[] = {0, 3, 211, 65536};
            static const SInt64 offsets[] = {0, 1, 1024, -1};
            static const int descriptorCounts[] = {0, 1, 2, 5};
            for (size_t n = 0; n < sizeof descriptorCounts / sizeof *descriptorCounts; n++) {
                CMItemCount count = (CMItemCount)descriptorCounts[n];
                AudioStreamPacketDescription *descriptions = count ? calloc(count, sizeof *descriptions) : NULL;
                CMBlockBufferRef block = blockOf(count * 4 + 8);
                for (size_t packet = 0; packet < count; packet++) {
                    descriptions[packet].mStartOffset = offsets[packet % 4];
                    descriptions[packet].mVariableFramesInPacket = frameCounts[packet % 3];
                    descriptions[packet].mDataByteSize = byteSizes[packet % 4];
                }
                for (size_t a = 0; a < sizeof frameCounts / sizeof *frameCounts; a++) {
                    AudioStreamBasicDescription stream = {0};
                    stream.mSampleRate = 44100;
                    stream.mFormatID = kAudioFormatMPEG4AAC;
                    stream.mFormatFlags = kMPEG4Object_AAC_LC;
                    stream.mChannelsPerFrame = 2;
                    stream.mFramesPerPacket = 1024;
                    CMAudioFormatDescriptionRef format = NULL;
                    if (CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &stream, 0, NULL, 0, NULL, NULL, &format))
                        continue;
                    for (int withPackets = 0; withPackets < 2; withPackets++)
                        for (int numeric = 0; numeric < 2; numeric++) {
                            CMSampleBufferRef system = NULL, port = NULL;
                            char name[128];
                            snprintf(name, sizeof name, "AudioSampleBufferCreate %lu packets, descriptions %s, pts %s", (unsigned long)count,
                                     withPackets ? "given" : "null", numeric ? "numeric" : "invalid");
                            CMTime pts = numeric ? CMTimeMake(count, 44100) : kCMTimeInvalid;
                            compare(name,
                                    CMAudioSampleBufferCreateReadyWithPacketDescriptions(kCFAllocatorDefault, block, format, count, pts,
                                                                                       withPackets ? descriptions : NULL, &system),
                                    system,
                                    CharonHostCMAudioSampleBufferCreateReadyWithPacketDescriptions(kCFAllocatorDefault, block, format, count, pts,
                                                                                              withPackets ? descriptions : NULL, &port),
                                    port, audioClaim((UInt32)count, withPackets ? descriptions : NULL, NO), 0);
                        }
                    for (size_t f = 0; f < sizeof frameCounts / sizeof *frameCounts; f++) {
                        AudioStreamBasicDescription plain = {0};
                        plain.mSampleRate = 48000;
                        plain.mFormatID = kAudioFormatLinearPCM;
                        plain.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
                        plain.mChannelsPerFrame = 1;
                        plain.mBitsPerChannel = 16;
                        plain.mBytesPerFrame = 2;
                        plain.mBytesPerPacket = 2;
                        plain.mFramesPerPacket = 1;
                        CMAudioFormatDescriptionRef linear = NULL;
                        if (CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &plain, 0, NULL, 0, NULL, NULL, &linear))
                            continue;
                        CMSampleBufferRef system = NULL, port = NULL;
                        char name[128];
                        snprintf(name, sizeof name, "AudioSampleBufferCreate linear, %lu packets, frames %u", (unsigned long)count, frameCounts[f]);
                        compare(name, CMAudioSampleBufferCreateReadyWithPacketDescriptions(kCFAllocatorDefault, block, linear, count, CMTimeMake(count, 48000), descriptions, &system), system,
                                CharonHostCMAudioSampleBufferCreateReadyWithPacketDescriptions(kCFAllocatorDefault, block, linear, count, CMTimeMake(count, 48000), descriptions, &port), port, 1, 0);
                        if (linear)
                            CFRelease(linear);
                    }
                    CFRelease(format);
                }
                free(descriptions);
                CFRelease(block);
            }
        }
        for (size_t n = 0; n < sizeof sampleCounts / sizeof *sampleCounts; n++)
            for (size_t t = 0; t < sizeof timingCounts / sizeof *timingCounts; t++) {
                CMBlockBufferRef block = blockOf(sampleCounts[n] * 8 + 4);
                size_t *sizes = calloc(sampleCounts[n] ? sampleCounts[n] : 1, sizeof *sizes);
                for (CMItemCount index = 0; index < sampleCounts[n]; index++)
                    sizes[index] = 8;
                CMSampleTimingInfo *timings = calloc(timingCounts[t] ? timingCounts[t] : 1, sizeof *timings);
                for (CMItemCount index = 0; index < timingCounts[t]; index++) {
                    timings[index].duration = CMTimeMake(index + 1, 30);
                    timings[index].presentationTimeStamp = CMTimeMake(index * 100, 30000);
                    timings[index].decodeTimeStamp = kCMTimeInvalid;
                }
                CMSampleBufferRef source = NULL;
                CMSampleBufferCreate(kCFAllocatorDefault, block, true, NULL, NULL, format, sampleCounts[n], timingCounts[t], timings, sampleCounts[n], sizes, &source);
                __block NSMutableString *seen = [NSMutableString string];
                __block int stop = 0;
                OSStatus a = CMSampleBufferCallBlockForEachSample(source, ^OSStatus(CMSampleBufferRef piece, CMItemCount index) {
                    [seen appendFormat:@"%lu:%@", (unsigned long)index, describe(piece, 1)];
                    if (index == 1)
                        stop = 1;
                    return stop ? -12345 : 0;
                });
                __block NSMutableString *mine = [NSMutableString string];
                __block int myStop = 0;
                OSStatus b = CharonHostCMSampleBufferCallBlockForEachSample(source, ^OSStatus(CMSampleBufferRef piece, CMItemCount index) {
                    [mine appendFormat:@"%lu:%@", (unsigned long)index, describe(piece, 1)];
                    if (index == 1)
                        myStop = 1;
                    return myStop ? -12345 : 0;
                });
                checks += insideClaim(sampleCounts[n], timingCounts[t]) ? 1 : 0;
                cornerSame += insideClaim(sampleCounts[n], timingCounts[t]) ? 0 : (a == b && [seen isEqualToString:mine]);
                cornerDifferent += insideClaim(sampleCounts[n], timingCounts[t]) ? 0 : (a != b || ![seen isEqualToString:mine]);
                if (insideClaim(sampleCounts[n], timingCounts[t]) && (a != b || ![seen isEqualToString:mine])) {
                    failures++;
                    if (failures < 30)
                        printf("DIFFERENT CallBlockForEachSample %lu samples %lu timings: status %d vs %d\n  system %s\n  port   %s\n",
                               (unsigned long)sampleCounts[n], (unsigned long)timingCounts[t], a, b, seen.UTF8String, mine.UTF8String);
                }
                __block int count = 0;
                compare("CallBlockForEachSample counting",
                        CMSampleBufferCallBlockForEachSample(source, ^OSStatus(CMSampleBufferRef piece, CMItemCount index) { count++; return 0; }), NULL,
                        CharonHostCMSampleBufferCallBlockForEachSample(source, ^OSStatus(CMSampleBufferRef piece, CMItemCount index) { count++; return 0; }), NULL,
                        insideClaim(sampleCounts[n], timingCounts[t]), 1);
                if (source)
                    CFRelease(source);
                free(sizes);
                free(timings);
                CFRelease(block);
            }
        if (pixels)
            CVPixelBufferRelease(pixels);
        if (format)
            CFRelease(format);
        printf("%d inside the claim, %d different; %d outside it, %d of those the same\n", checks, failures, cornerSame + cornerDifferent, cornerSame);
    }
    return failures != 0;
}
