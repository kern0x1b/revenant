#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#define SAMPLE_RATE 44100.0
#define WRITE_FRAMES 11025
#define BLOCK_FRAMES 1000

static void describe(const char *label, AVAudioFormat *format)
{
    if (!format) {
        printf("%s: nil\n", label);
        return;
    }
    const AudioStreamBasicDescription *asbd = format.streamDescription;
    printf("%s: formatID=%c%c%c%c sampleRate=%g channels=%u commonFormat=%d interleaved=%d\n", label,
           (char)(asbd->mFormatID >> 24), (char)(asbd->mFormatID >> 16), (char)(asbd->mFormatID >> 8), (char)asbd->mFormatID,
           format.sampleRate, (unsigned)format.channelCount, (int)format.commonFormat, format.interleaved ? 1 : 0);
}

static void describeError(const char *label, NSError *error)
{
    if (!error)
        printf("%s: no error\n", label);
    else
        printf("%s: error domain=%s code=%ld\n", label, error.domain.UTF8String, (long)error.code);
}

static unsigned long checksumBytes(const void *bytes, size_t count, unsigned long hash)
{
    const unsigned char *p = bytes;
    for (size_t i = 0; i < count; i++) {
        hash ^= p[i];
        hash *= 16777619UL;
    }
    return hash;
}

static NSDictionary *linearPCMSettings(void)
{
    return @{AVFormatIDKey: @(kAudioFormatLinearPCM),
             AVSampleRateKey: @(SAMPLE_RATE),
             AVNumberOfChannelsKey: @1,
             AVLinearPCMBitDepthKey: @16,
             AVLinearPCMIsFloatKey: @NO,
             AVLinearPCMIsBigEndianKey: @NO,
             AVLinearPCMIsNonInterleaved: @NO};
}

static NSDictionary *aacSettings(void)
{
    return @{AVFormatIDKey: @(kAudioFormatMPEG4AAC),
             AVSampleRateKey: @(SAMPLE_RATE),
             AVNumberOfChannelsKey: @1,
             AVEncoderBitRateKey: @64000};
}

static AVAudioPCMBuffer *sineBuffer(AVAudioFormat *format, AVAudioFrameCount frames)
{
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:frames];
    float *samples = buffer.floatChannelData[0];
    for (AVAudioFrameCount i = 0; i < frames; i++)
        samples[i] = (float)(0.5 * sin(2.0 * M_PI * 440.0 * (double)i / SAMPLE_RATE));
    buffer.frameLength = frames;
    return buffer;
}

static void readAll(AVAudioFile *file, const char *label)
{
    AVAudioFormat *format = file.processingFormat;
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:BLOCK_FRAMES];
    unsigned long frames = 0, hash = 2166136261UL;
    NSError *error = nil;
    for (;;) {
        if (![file readIntoBuffer:buffer error:&error]) {
            describeError(label, error);
            break;
        }
        if (buffer.frameLength == 0)
            break;
        size_t width = format.commonFormat == AVAudioPCMFormatInt16 ? 2 : 4;
        const void *first = format.commonFormat == AVAudioPCMFormatInt16 ? (const void *)buffer.int16ChannelData[0]
                                                                        : (const void *)buffer.floatChannelData[0];
        if (!format.interleaved)
            hash = checksumBytes(first, (size_t)buffer.frameLength * width, hash);
        else
            hash = checksumBytes(first, (size_t)buffer.frameLength * width * format.channelCount, hash);
        frames += buffer.frameLength;
    }
    printf("%s: frames=%lu checksum=%08lx\n", label, frames, hash & 0xffffffffUL);
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: probe <scratch-directory>\n");
            return 2;
        }
        NSURL *directory = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
        NSURL *caf = [directory URLByAppendingPathComponent:@"sine.caf"];
        NSURL *m4a = [directory URLByAppendingPathComponent:@"sine.m4a"];
        NSURL *missing = [directory URLByAppendingPathComponent:@"absent.caf"];
        [[NSFileManager defaultManager] removeItemAtURL:caf error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:m4a error:nil];

        NSError *error = nil;

        @autoreleasepool {
            AVAudioFile *writer = [[AVAudioFile alloc] initForWriting:caf settings:linearPCMSettings() error:&error];
            describeError("write caf", error);
            if (!writer)
                return 1;
            describe("write caf fileFormat", writer.fileFormat);
            describe("write caf processingFormat", writer.processingFormat);
            printf("write caf url=%s\n", writer.url.lastPathComponent.UTF8String);
            AVAudioPCMBuffer *sine = sineBuffer(writer.processingFormat, WRITE_FRAMES);
            BOOL wrote = [writer writeFromBuffer:sine error:&error];
            describeError("write caf frames", wrote ? nil : error);
            printf("write caf length=%lld\n", (long long)writer.length);
        }

        @autoreleasepool {
            AVAudioFile *reader = [[AVAudioFile alloc] initForReading:caf error:&error];
            describeError("read caf", error);
            describe("read caf fileFormat", reader.fileFormat);
            describe("read caf processingFormat", reader.processingFormat);
            printf("read caf url=%s length=%lld framePosition=%lld\n", reader.url.lastPathComponent.UTF8String,
                   (long long)reader.length, (long long)reader.framePosition);
            readAll(reader, "read caf float all");

            reader.framePosition = 1000;
            printf("seek caf framePosition=%lld\n", (long long)reader.framePosition);
            AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:reader.processingFormat frameCapacity:BLOCK_FRAMES];
            BOOL ok = [reader readIntoBuffer:buffer frameCount:500 error:&error];
            describeError("read caf count error", ok ? nil : error);
            unsigned long hash = checksumBytes(buffer.floatChannelData[0], (size_t)buffer.frameLength * sizeof(float), 2166136261UL);
            printf("read caf count frames=%u checksum=%08lx framePosition=%lld\n", (unsigned)buffer.frameLength,
                   hash & 0xffffffffUL, (long long)reader.framePosition);
        }

        @autoreleasepool {
            AVAudioFile *reader = [[AVAudioFile alloc] initForReading:caf commonFormat:AVAudioPCMFormatInt16 interleaved:YES error:&error];
            describeError("read caf int16", error);
            describe("read caf int16 fileFormat", reader.fileFormat);
            describe("read caf int16 processingFormat", reader.processingFormat);
            printf("read caf int16 length=%lld\n", (long long)reader.length);
            readAll(reader, "read caf int16 all");
        }

        @autoreleasepool {
            AVAudioFile *writer = [[AVAudioFile alloc] initForWriting:m4a settings:aacSettings() error:&error];
            describeError("write m4a", error);
            if (!writer)
                return 1;
            AVAudioPCMBuffer *sine = sineBuffer(writer.processingFormat, WRITE_FRAMES);
            BOOL wrote = [writer writeFromBuffer:sine error:&error];
            describeError("write m4a frames", wrote ? nil : error);
        }

        @autoreleasepool {
            AVAudioFile *reader = [[AVAudioFile alloc] initForReading:m4a error:&error];
            describeError("read m4a", error);
            describe("read m4a fileFormat", reader.fileFormat);
            describe("read m4a processingFormat", reader.processingFormat);
            printf("read m4a length=%lld\n", (long long)reader.length);
            AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:reader.processingFormat frameCapacity:BLOCK_FRAMES];
            unsigned long frames = 0;
            for (;;) {
                if (![reader readIntoBuffer:buffer error:&error]) {
                    describeError("read m4a loop", error);
                    break;
                }
                if (buffer.frameLength == 0)
                    break;
                frames += buffer.frameLength;
            }
            printf("read m4a frames=%lu\n", frames);
        }

        @autoreleasepool {
            AVAudioFile *reader = [[AVAudioFile alloc] initForReading:caf error:&error];
            AVAudioFormat *stereo = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:SAMPLE_RATE channels:2];
            AVAudioPCMBuffer *other = [[AVAudioPCMBuffer alloc] initWithPCMFormat:stereo frameCapacity:BLOCK_FRAMES];
            error = nil;
            BOOL wrongFormat = [reader readIntoBuffer:other error:&error];
            printf("read other format: %s\n", wrongFormat ? "read" : "refused");
            describeError("read other format", error);
            AVAudioPCMBuffer *small = [[AVAudioPCMBuffer alloc] initWithPCMFormat:reader.processingFormat frameCapacity:BLOCK_FRAMES];
            error = nil;
            @try {
                BOOL tooMany = [reader readIntoBuffer:small frameCount:BLOCK_FRAMES + 1 error:&error];
                printf("read past capacity: %s\n", tooMany ? "read" : "refused");
                describeError("read past capacity", error);
            } @catch (NSException *exception) {
                printf("read past capacity: raised name=%s reason=%s\n", exception.name.UTF8String, exception.reason.UTF8String);
            }
        }

        error = nil;
        AVAudioFile *absent = [[AVAudioFile alloc] initForReading:missing error:&error];
        printf("missing file: %s\n", absent ? "opened" : "nil");
        describeError("missing file", error);

        error = nil;
        NSDictionary *noChannels = @{AVFormatIDKey: @(kAudioFormatLinearPCM), AVSampleRateKey: @(SAMPLE_RATE), AVNumberOfChannelsKey: @0};
        AVAudioFile *badChannels = [[AVAudioFile alloc] initForWriting:[directory URLByAppendingPathComponent:@"bad.caf"] settings:noChannels error:&error];
        printf("bad channels: %s\n", badChannels ? "opened" : "nil");
        describeError("bad channels", error);
        if (badChannels) {
            describe("bad channels fileFormat", badChannels.fileFormat);
            describe("bad channels processingFormat", badChannels.processingFormat);
            printf("bad channels length=%lld\n", (long long)badChannels.length);
        }

        error = nil;
        NSDictionary *unknownFormat = @{AVFormatIDKey: @(0x7a7a7a7a), AVSampleRateKey: @(SAMPLE_RATE), AVNumberOfChannelsKey: @1};
        AVAudioFile *badFormat = [[AVAudioFile alloc] initForWriting:[directory URLByAppendingPathComponent:@"bad.caf"] settings:unknownFormat error:&error];
        printf("bad format: %s\n", badFormat ? "opened" : "nil");
        describeError("bad format", error);
    }
    return 0;
}
