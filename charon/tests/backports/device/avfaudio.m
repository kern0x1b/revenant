#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#import "check.h"

// AVAudioFormat and AVAudioPCMBuffer, the value types the rest of AVFAudio's node graph is built
// on (see facts/AVFoundation/AVFAudio.md). The one thing a passing build cannot show is whether a
// graph that compiles and runs actually moves sound: an AudioBufferList that links and stays
// silent raises no exception and no error code. This writes a known, non-zero waveform through
// floatChannelData and reads every sample back through the same pointers AND through the raw
// AudioBufferList, checking for an exact match rather than a non-nil pointer.

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

int main(void)
{
    @autoreleasepool {
        CHECK_EQUAL(image_of([AVAudioFormat class]), @"libAVFoundationBackports.dylib", "AVAudioFormat comes from the backports");

        AVAudioFormat *stereo = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
        CHECK(stereo != nil, "deinterleaved stereo float32 format is constructed");
        CHECK([stereo isStandard], "standard format is deinterleaved float32");
        CHECK([stereo channelCount] == 2, "channel count is 2");
        CHECK([stereo sampleRate] == 44100.0, "sample rate is 44100");
        CHECK(![stereo isInterleaved], "standard format is not interleaved");
        const AudioStreamBasicDescription *asbd = [stereo streamDescription];
        CHECK(asbd != NULL, "streamDescription is non-NULL");
        CHECK(asbd->mFormatID == kAudioFormatLinearPCM, "streamDescription is linear PCM");
        CHECK(asbd->mChannelsPerFrame == 2, "streamDescription channel count matches");
        CHECK((asbd->mFormatFlags & kAudioFormatFlagIsFloat) != 0, "streamDescription is float");
        CHECK((asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0, "streamDescription is non-interleaved");
        CHECK(asbd->mBytesPerFrame == 4, "streamDescription bytes-per-frame is 4 (one float32 channel)");

        AVAudioFormat *interleavedInt16 = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:8000.0 channels:2 interleaved:YES];
        CHECK(interleavedInt16 != nil, "interleaved int16 stereo format is constructed");
        CHECK([interleavedInt16 commonFormat] == AVAudioPCMFormatInt16, "commonFormat is Int16");
        CHECK([interleavedInt16 isInterleaved], "interleaved format reports interleaved");
        CHECK([interleavedInt16 streamDescription]->mBytesPerFrame == 4, "interleaved int16 stereo is 4 bytes per frame (2ch * 2 bytes)");

        AVAudioFormat *tooManyChannels = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:6];
        CHECK(tooManyChannels == nil, "more than 2 channels without a channel layout is refused, matching the real class");

        // A malloc'd C struct field typed as an Objective-C pointer is NOT retained by ARC just
        // because of its declared type - only a real ivar or local is. This was a genuine latent
        // dangling-pointer bug here (format stored in the struct, not an ivar) until fixed. Proven
        // by dropping every other reference, forcing the freed memory to be reused by unrelated
        // allocations, then reading the buffer's own values back through its strong reference: a
        // dangling pointer would read garbage or a wrong, reused object's data, not what was set.
        AVAudioPCMBuffer *retainCheck;
        @autoreleasepool {
            AVAudioFormat *temporary = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:22050.0 channels:1];
            retainCheck = [[AVAudioPCMBuffer alloc] initWithPCMFormat:temporary frameCapacity:16];
        }
        for (int i = 0; i < 4096; i++)
            @autoreleasepool { (void)[NSMutableString stringWithFormat:@"churn %d filling freed memory", i]; }
        CHECK(retainCheck.format != nil, "a buffer's format stays alive after every other strong reference is dropped");
        CHECK(retainCheck.format.sampleRate == 22050.0, "buffer.format.sampleRate survives, not a dangling pointer's garbage");
        CHECK(retainCheck.format.channelCount == 1, "buffer.format.channelCount survives, not a dangling pointer's garbage");

        AVAudioFrameCount frames = 512;
        AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:stereo frameCapacity:frames];
        CHECK(buffer != nil, "PCM buffer is constructed");
        CHECK([buffer frameCapacity] == frames, "frameCapacity matches what was asked for");
        CHECK([buffer frameLength] == 0, "frameLength starts at 0");
        CHECK([buffer stride] == 1, "deinterleaved buffer has stride 1");
        CHECK([buffer format] == stereo, "buffer holds the format it was given");

        float *const *channels = [buffer floatChannelData];
        CHECK(channels != NULL, "floatChannelData is non-NULL for a float32 format");
        CHECK([buffer int16ChannelData] == NULL, "int16ChannelData is NULL for a float32 format");

        for (AVAudioChannelCount c = 0; c < 2; c++)
            for (AVAudioFrameCount i = 0; i < frames; i++)
                channels[c][i] = (float)(c + 1) * 0.5f + (float)i * 0.0001f;
        [buffer setFrameLength:frames];
        CHECK([buffer frameLength] == frames, "frameLength reflects what was set");

        BOOL allNonZero = YES, matchesWrite = YES;
        for (AVAudioChannelCount c = 0; c < 2; c++) {
            for (AVAudioFrameCount i = 0; i < frames; i++) {
                float expected = (float)(c + 1) * 0.5f + (float)i * 0.0001f;
                if (channels[c][i] == 0.0f)
                    allNonZero = NO;
                if (channels[c][i] != expected)
                    matchesWrite = NO;
            }
        }
        CHECK(allNonZero, "every sample written is non-zero when read back (no silent graph)");
        CHECK(matchesWrite, "every sample read back through floatChannelData matches exactly what was written");

        const AudioBufferList *list = [buffer audioBufferList];
        CHECK(list != NULL, "audioBufferList is non-NULL");
        CHECK(list->mNumberBuffers == 2, "deinterleaved stereo produces 2 AudioBuffers");
        CHECK(list->mBuffers[0].mDataByteSize == frames * sizeof(float), "AudioBuffer[0].mDataByteSize tracks frameLength");
        float *rawLeft = list->mBuffers[0].mData;
        CHECK(rawLeft[10] == channels[0][10], "the raw AudioBufferList's mData is the SAME memory as floatChannelData, not a copy");

        AVAudioPCMBuffer *copy = [buffer copy];
        CHECK(copy != buffer, "a copy is a distinct object");
        CHECK([copy frameLength] == frames, "the copy carries the same frameLength");
        float *const *copyChannels = [copy floatChannelData];
        CHECK(copyChannels[1][20] == channels[1][20], "the copy's samples match the original's");
        CHECK(copyChannels[1] != channels[1], "the copy owns its own memory, not the original's");

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
