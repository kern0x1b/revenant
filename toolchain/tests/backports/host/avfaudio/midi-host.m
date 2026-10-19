#import <AVFoundation/AVFoundation.h>
#import <CoreMIDI/MIDIServices.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static AVAudioEngine *engine;
static AVAudioUnitSampler *sampler;
static AVAudioEngineManualRenderingBlock render;
static AVAudioFormat *format;
static const AVAudioFrameCount kFrames = 4096;
static int failures = 0;
static int checks = 0;

static void setup(void)
{
    engine = [[AVAudioEngine alloc] init];
    sampler = [[AVAudioUnitSampler alloc] init];
    format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
    [engine attachNode:sampler];
    [engine connect:sampler to:engine.mainMixerNode format:format];
    NSError *error = nil;
    if (![engine enableManualRenderingMode:AVAudioEngineManualRenderingModeOffline format:format maximumFrameCount:4096 error:&error]) {
        printf("FAIL the manual rendering mode: %s\n", error.description.UTF8String);
        exit(1);
    }
    render = engine.manualRenderingBlock;
    NSURL *bank = [NSURL fileURLWithPath:@"/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"];
    if (![sampler loadSoundBankInstrumentAtURL:bank program:0 bankMSB:kAUSampler_DefaultMelodicBankMSB bankLSB:0 error:&error]) {
        printf("FAIL the sound bank: %s\n", error.description.UTF8String);
        exit(1);
    }
    if (![engine startAndReturnError:&error]) {
        printf("FAIL the engine start: %s\n", error.description.UTF8String);
        exit(1);
    }
}

static NSData *block(void)
{
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:kFrames];
    buffer.frameLength = kFrames;
    OSStatus status = noErr;
    render(kFrames, buffer.mutableAudioBufferList, &status);
    NSMutableData *data = [NSMutableData dataWithLength:kFrames * 2 * sizeof(float)];
    float *out = data.mutableBytes;
    for (AVAudioFrameCount i = 0; i < kFrames; i++) {
        out[2 * i] = buffer.floatChannelData[0][i];
        out[2 * i + 1] = buffer.floatChannelData[1][i];
    }
    return data;
}

static uint32_t gWords[2];
static void sendType4(uint32_t word0, uint32_t word1)
{
    gWords[0] = word0;
    gWords[1] = word1;
    uint8_t storage[256];
    MIDIEventList *list = (MIDIEventList *)storage;
    MIDIEventPacket *packet = MIDIEventListInit(list, kMIDIProtocol_2_0);
    MIDIEventListAdd(list, sizeof storage, packet, 0, 2, gWords);
    [sampler sendMIDIEventList:list];
}

static NSData *render_(void (^send)(void))
{
    [engine stop];
    setup();
    send();
    return block();
}

static double energy(NSData *d)
{
    const float *f = d.bytes;
    double s = 0;
    for (NSUInteger i = 0; i < d.length / sizeof(float); i++) {
        s += fabs(f[i]);
    }
    return s;
}

static void equivalent(const char *name, NSData *fromList, NSData *fromRule)
{
    checks++;
    BOOL same = fromList.length == fromRule.length && memcmp(fromList.bytes, fromRule.bytes, fromList.length) == 0;
    printf("%s: %s\n", name, same ? "bit-exact" : "DIFFERENT");
    if (!same) {
        failures++;
    }
}

int main(void)
{
    @autoreleasepool {
        setup();
        NSData *silent = render_(^{});
        NSData *note = render_(^{ [sampler sendMIDIEvent:0x90 data1:60 data2:127]; });
        if (energy(note) <= 0 || energy(silent) != 0) {
            printf("FAIL the control: the sampler does not sound, so no comparison means anything\n");
            return 1;
        }

        const uint32_t velocities16[] = {0xFFFF0000u, 0x80000000u, 0x7FFF0000u, 0x01000000u, 0x00010000u, 0xFE000000u, 0x3F000000u, 0xC0000000u, 0x00000000u};
        for (size_t i = 0; i < sizeof velocities16 / sizeof velocities16[0]; i++) {
            uint32_t word1 = velocities16[i];
            uint32_t v16 = word1 >> 16;
            uint8_t rule = (uint8_t)(v16 >> 9);
            if (rule == 0) {
                rule = 1;
            }
            NSData *list = render_(^{ sendType4(0x40903C00u, word1); });
            NSData *want = render_(^{ [sampler sendMIDIEvent:0x90 data1:60 data2:rule]; });
            char name[96];
            snprintf(name, sizeof name, "note on velocity16 0x%04X -> velocity %d", v16, rule);
            equivalent(name, list, want);
        }

        const uint32_t values32[] = {0xFFFFFFFFu, 0x80000000u, 0x40000000u, 0x7FFFFFFFu, 0x00000001u};
        for (size_t i = 0; i < sizeof values32 / sizeof values32[0]; i++) {
            uint32_t word1 = values32[i];
            uint8_t rule = (uint8_t)(word1 >> 25);
            NSData *list = render_(^{ sendType4(0x40B30700u, word1); [sampler sendMIDIEvent:0x90 data1:60 data2:127]; });
            NSData *want = render_(^{ [sampler sendMIDIEvent:0xB0 data1:7 data2:rule]; [sampler sendMIDIEvent:0x90 data1:60 data2:127]; });
            char name[96];
            snprintf(name, sizeof name, "controller 7 value32 0x%08X -> value %d", word1, rule);
            equivalent(name, list, want);
        }

        const uint32_t bends32[] = {0xFFFFFFFFu, 0x00000000u, 0xC0000000u, 0x80000001u};
        for (size_t i = 0; i < sizeof bends32 / sizeof bends32[0]; i++) {
            uint32_t word1 = bends32[i];
            uint32_t bend = word1 >> 18;
            NSData *list = render_(^{ sendType4(0x40E00000u, word1); [sampler sendMIDIEvent:0x90 data1:60 data2:127]; });
            NSData *want = render_(^{ [sampler sendMIDIEvent:0xE0 data1:(bend & 0x7F) data2:(bend >> 7)]; [sampler sendMIDIEvent:0x90 data1:60 data2:127]; });
            char name[96];
            snprintf(name, sizeof name, "pitch bend value32 0x%08X -> 14-bit %u", word1, bend);
            equivalent(name, list, want);
        }

        printf("checks=host-midi-equivalence failures=%d\n", failures);
        printf("not observable on the sampler (reported, not checked): note off velocity, program change, channel and poly pressure, system messages, sysex\n");
        return failures == 0 ? 0 : 1;
    }
}
