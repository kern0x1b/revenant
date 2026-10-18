// The iOS 7 to 15 AudioToolbox functions this round carries (packages/a/apple-backports/AVFAudio/AudioToolboxFunctions{7,9,11,15}.m),
// each checked against the host's own function of the same name, called through dlsym, for the same input.
//
// The port's functions are compiled into this file under a CharonTest name (functions.sh passes -D<Name>=CharonTest<Name>),
// so the host's symbol and the port's definition can sit in one process. The host's answers are the oracle; a port answer
// that differs from the host's on any case fails the check.
//
// Not checked here, and why: AudioOutputUnitGetHostIcon's port definition is iOS-only (its return type is UIImage, which
// macOS does not have), so the port's icon is not compiled on the host; the host's own answer is printed for the record.
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMIDI/MIDIServices.h>
#import <dlfcn.h>
#import <pthread.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static int checks = 0;
static int failures = 0;

static void check(int passed, const char *name)
{
    checks++;
    if (!passed) {
        failures++;
        printf("FAIL %s\n", name);
    }
}

static void *hostSymbol(const char *name)
{
    static void *handle;
    if (handle == NULL) {
        handle = dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_NOW);
    }
    void *symbol = dlsym(handle, name);
    if (symbol == NULL) {
        printf("FAIL the host has no %s\n", name);
        exit(1);
    }
    return symbol;
}

typedef double (*LastActiveFn)(AudioComponent);
typedef id (*HostIconFn)(AudioUnit, float);
typedef CFArrayRef (*CopyListFn)(CFStringRef);
typedef OSStatus (*SetListFn)(CFStringRef, CFArrayRef);
typedef void (*InstantiateFn)(AudioComponent, UInt32, void (^)(AudioComponentInstance, OSStatus));
typedef void (*PlaySoundFn)(SystemSoundID, void (^)(void));
typedef OSStatus (*MIDIListFn)(MusicDeviceComponent, UInt32, const MIDIEventList *);

// The port's definitions, compiled from packages/a/apple-backports/AVFAudio/AudioToolboxFunctions{7,9,11,15}.m under these
// names (functions.sh). The SDK's own declarations of these names are not used here: the macOS header marks some of them
// unavailable, and the port's definitions are the ones under test.
CFAbsoluteTime CharonTestAudioComponentGetLastActiveTime(AudioComponent comp);
CFArrayRef CharonTestAudioUnitExtensionCopyComponentList(CFStringRef extensionIdentifier);
OSStatus CharonTestAudioUnitExtensionSetComponentList(CFStringRef extensionIdentifier, CFArrayRef audioComponentInfo);
void CharonTestAudioComponentInstantiate(AudioComponent inComponent, AudioComponentInstantiationOptions inOptions,
                                         void (^inCompletionHandler)(AudioComponentInstance _Nullable, OSStatus));
void CharonTestAudioServicesPlaySystemSoundWithCompletion(SystemSoundID inSystemSoundID, void (^inCompletionBlock)(void));
void CharonTestAudioServicesPlayAlertSoundWithCompletion(SystemSoundID inSystemSoundID, void (^inCompletionBlock)(void));
OSStatus CharonTestMusicDeviceMIDIEventList(MusicDeviceComponent inUnit, UInt32 inOffsetSampleFrame, const MIDIEventList *evtList);

static AudioComponent genericOutput(void)
{
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_GenericOutput;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    return AudioComponentFindNext(NULL, &description);
}

// The last-active time: the host's answer for a component before and after it is instantiated and initialized.
static void checkLastActive(void)
{
    LastActiveFn hostLastActive = hostSymbol("AudioComponentGetLastActiveTime");
    AudioComponent component = genericOutput();
    check(CharonTestAudioComponentGetLastActiveTime(component) == hostLastActive(component),
          "AudioComponentGetLastActiveTime: the port's answer is the host's before any use");

    AudioComponentInstance instance = NULL;
    AudioComponentInstanceNew(component, &instance);
    AudioUnitInitialize(instance);
    check(CharonTestAudioComponentGetLastActiveTime(component) == hostLastActive(component),
          "AudioComponentGetLastActiveTime: the port's answer is the host's after instantiation and initialization");
    AudioComponentInstanceDispose(instance);
}

// The host application icon: the host's answer is nil for a unit it has in this process (printed; the port's
// definition is iOS-only, see the comment at the top of this file).
static void printHostIcon(void)
{
    HostIconFn hostIcon = hostSymbol("AudioOutputUnitGetHostIcon");
    AudioComponentInstance instance = NULL;
    AudioComponentInstanceNew(genericOutput(), &instance);
    printf("host: AudioOutputUnitGetHostIcon(generic output instance, 32) is %s\n",
           hostIcon((AudioUnit)instance, 32) == nil ? "nil" : "non-nil");
    AudioComponentInstanceDispose(instance);
}

// The extension lists: the host's status and the port's are the same for an unknown identifier, a NULL identifier, an empty
// list and a list with one component description.
static void checkExtensionLists(void)
{
    CopyListFn hostCopy = hostSymbol("AudioUnitExtensionCopyComponentList");
    SetListFn hostSet = hostSymbol("AudioUnitExtensionSetComponentList");
    NSDictionary *info = @{ @"type": @"aumu", @"subtype": @"Test", @"manufacturer": @"Test", @"name": @"x" };
    CFStringRef unknown = CFSTR("no.such.extension");

    check(CharonTestAudioUnitExtensionCopyComponentList(unknown) == hostCopy(unknown),
          "AudioUnitExtensionCopyComponentList: an unknown identifier answers what the host answers");
    check(CharonTestAudioUnitExtensionSetComponentList(unknown, (__bridge CFArrayRef)@[]) == hostSet(unknown, (__bridge CFArrayRef)@[]),
          "AudioUnitExtensionSetComponentList: an unknown identifier and an empty list answer what the host answers");
    check(CharonTestAudioUnitExtensionSetComponentList(unknown, (__bridge CFArrayRef)@[info]) == hostSet(unknown, (__bridge CFArrayRef)@[info]),
          "AudioUnitExtensionSetComponentList: an unknown identifier and one description answer what the host answers");
    check(CharonTestAudioUnitExtensionCopyComponentList(unknown) == NULL && hostCopy(unknown) == NULL,
          "AudioUnitExtensionCopyComponentList: nothing is listed for an identifier nobody set");
    check(CharonTestAudioUnitExtensionSetComponentList(NULL, (__bridge CFArrayRef)@[]) == hostSet(NULL, (__bridge CFArrayRef)@[]),
          "AudioUnitExtensionSetComponentList: a NULL identifier answers what the host answers");
    check(CharonTestAudioUnitExtensionCopyComponentList(NULL) == hostCopy(NULL),
          "AudioUnitExtensionCopyComponentList: a NULL identifier answers what the host answers");
}

// AudioComponentInstantiate: the handler is called before the call returns, on the calling thread, with an instance and status
// 0 for a component, and with no instance and -3000 for no component. The host's answers are the same.
static void checkInstantiate(void)
{
    InstantiateFn hostInstantiate = hostSymbol("AudioComponentInstantiate");
    for (int side = 0; side < 2; side++) {
        __block BOOL returned = NO;
        __block BOOL calledBeforeReturn = NO;
        __block BOOL onMain = NO;
        __block OSStatus status = 0;
        __block AudioComponentInstance instance = NULL;
        void (^handler)(AudioComponentInstance, OSStatus) = ^(AudioComponentInstance made, OSStatus result) {
            calledBeforeReturn = !returned;
            onMain = pthread_main_np();
            status = result;
            instance = made;
        };
        if (side == 0) {
            CharonTestAudioComponentInstantiate(genericOutput(), 0, handler);
        } else {
            hostInstantiate(genericOutput(), 0, handler);
        }
        returned = YES;
        check(calledBeforeReturn, side == 0 ? "AudioComponentInstantiate: the port's handler is called before the call returns"
                                            : "AudioComponentInstantiate: the host's handler is called before the call returns (oracle)");
        check(onMain, side == 0 ? "AudioComponentInstantiate: the port's handler runs on the calling thread (the main thread)"
                                : "AudioComponentInstantiate: the host's handler runs on the calling thread (oracle)");
        check(status == 0 && instance != NULL, side == 0 ? "AudioComponentInstantiate: the port's answer for a component is an instance and status 0"
                                                         : "AudioComponentInstantiate: the host's answer for a component is an instance and status 0");
        if (instance != NULL) {
            AudioComponentInstanceDispose(instance);
        }
    }

    __block OSStatus portStatus = 0;
    __block OSStatus hostStatus = 0;
    __block AudioComponentInstance portInstance = (AudioComponentInstance)1;
    __block AudioComponentInstance hostInstance = (AudioComponentInstance)1;
    CharonTestAudioComponentInstantiate(NULL, 0, ^(AudioComponentInstance made, OSStatus result) {
        portInstance = made;
        portStatus = result;
    });
    hostInstantiate(NULL, 0, ^(AudioComponentInstance made, OSStatus result) {
        hostInstance = made;
        hostStatus = result;
    });
    check(portStatus == hostStatus && portInstance == NULL && hostInstance == NULL,
          "AudioComponentInstantiate: no component answers what the host answers (no instance, the same status)");
}

// The sound functions: the completion runs once, off the main thread, after the play call, for a valid and an invalid sound
// ID. The host's answer is the same, so the port's is checked against the same limits.
static void checkSoundCompletions(void)
{
    PlaySoundFn hostPlaySystem = hostSymbol("AudioServicesPlaySystemSoundWithCompletion");
    PlaySoundFn hostPlayAlert = hostSymbol("AudioServicesPlayAlertSoundWithCompletion");
    struct { const char *name; PlaySoundFn host; SystemSoundID sound; } cases[] = {
        { "AudioServicesPlaySystemSoundWithCompletion, 1104", hostPlaySystem, 1104 },
        { "AudioServicesPlaySystemSoundWithCompletion, invalid", hostPlaySystem, 0xFFFFFFFF },
        { "AudioServicesPlayAlertSoundWithCompletion, 1104", hostPlayAlert, 1104 },
        { "AudioServicesPlayAlertSoundWithCompletion, invalid", hostPlayAlert, 0xFFFFFFFF },
    };
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++) {
        for (int side = 0; side < 2; side++) {
            dispatch_semaphore_t done = dispatch_semaphore_create(0);
            __block BOOL onMain = YES;
            void (^completion)(void) = ^{
                onMain = pthread_main_np();
                dispatch_semaphore_signal(done);
            };
            if (side == 0) {
                if (i == 0 || i == 1) {
                    CharonTestAudioServicesPlaySystemSoundWithCompletion(cases[i].sound, completion);
                } else {
                    CharonTestAudioServicesPlayAlertSoundWithCompletion(cases[i].sound, completion);
                }
            } else {
                cases[i].host(cases[i].sound, completion);
            }
            BOOL fired = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
            char label[160];
            snprintf(label, sizeof label, "%s %s: the completion runs once, within 2 s", side == 0 ? "port" : "host", cases[i].name);
            check(fired, label);
            snprintf(label, sizeof label, "%s %s: the completion is off the main thread", side == 0 ? "port" : "host", cases[i].name);
            check(fired && !onMain, label);
        }
    }

    // A NULL block plays the sound and returns; nothing is called.
    CharonTestAudioServicesPlaySystemSoundWithCompletion(1104, NULL);
    CharonTestAudioServicesPlayAlertSoundWithCompletion(1104, NULL);
    check(1, "AudioServices*WithCompletion: a NULL block plays and returns");
}

// MusicDeviceMIDIEventList: the port's list walk and the host's list call render the sampler the same, bit for bit, for each
// list; the status is the same too. Each render is from a fresh engine with one sampler (the sound bank is the host's
// General MIDI bank).
typedef struct {
    AVAudioEngine *engine;
    AVAudioUnitSampler *sampler;
    AVAudioEngineManualRenderingBlock render;
    AVAudioFormat *format;
} SamplerRig;

static SamplerRig makeRig(void)
{
    SamplerRig rig;
    rig.engine = [[AVAudioEngine alloc] init];
    rig.sampler = [[AVAudioUnitSampler alloc] init];
    rig.format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
    [rig.engine attachNode:rig.sampler];
    [rig.engine connect:rig.sampler to:rig.engine.mainMixerNode format:rig.format];
    NSError *error = nil;
    [rig.engine enableManualRenderingMode:AVAudioEngineManualRenderingModeOffline format:rig.format maximumFrameCount:4096 error:&error];
    rig.render = rig.engine.manualRenderingBlock;
    NSURL *bank = [NSURL fileURLWithPath:@"/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"];
    [rig.sampler loadSoundBankInstrumentAtURL:bank program:0 bankMSB:kAUSampler_DefaultMelodicBankMSB bankLSB:0 error:&error];
    [rig.engine startAndReturnError:&error];
    return rig;
}

static const AVAudioFrameCount kFrames = 4096;

// The render after one list is sent to the sampler, and the status the send returned.
static NSData *renderAfterList(MIDIListFn send, const uint32_t *words, int count, OSStatus *status)
{
    SamplerRig rig = makeRig();
    uint8_t storage[256];
    MIDIEventList *list = (MIDIEventList *)storage;
    MIDIEventPacket *packet = MIDIEventListInit(list, kMIDIProtocol_2_0);
    MIDIEventListAdd(list, sizeof storage, packet, 0, (ByteCount)count, words);
    *status = send((MusicDeviceComponent)rig.sampler.audioUnit, 0, list);
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:rig.format frameCapacity:kFrames];
    buffer.frameLength = kFrames;
    OSStatus renderStatus = noErr;
    rig.render(kFrames, buffer.mutableAudioBufferList, &renderStatus);
    NSMutableData *data = [NSMutableData dataWithLength:kFrames * 2 * sizeof(float)];
    float *out = data.mutableBytes;
    for (AVAudioFrameCount i = 0; i < kFrames; i++) {
        out[2 * i] = buffer.floatChannelData[0][i];
        out[2 * i + 1] = buffer.floatChannelData[1][i];
    }
    return data;
}

static double energy(NSData *data)
{
    const float *samples = data.bytes;
    double sum = 0;
    for (size_t i = 0; i < data.length / sizeof(float); i++) {
        sum += (double)samples[i] * samples[i];
    }
    return sum;
}

static void checkMIDIList(void)
{
    MIDIListFn hostList = hostSymbol("MusicDeviceMIDIEventList");
    // Type 2: note on, middle C, velocity 100.
    uint32_t noteOn2[] = { (0x2u << 28) | (0x90u << 16) | (60u << 8) | 100u };
    // Type 4: note on, middle C, velocity16 0x8000 (velocity 64) and 0xFFFF (velocity 127).
    uint32_t noteOn4Half[] = { (0x4u << 28) | (0x9u << 20) | (60u << 8), 0x80000000u };
    uint32_t noteOn4Full[] = { (0x4u << 28) | (0x9u << 20) | (60u << 8), 0xFFFF0000u };
    // Type 4: control change 7, value32 0xFFFFFFFF (127), and pitch bend, value32 0xFFFFFFFF (16383), each after the note.
    uint32_t noteThenControl[] = { noteOn2[0], (0x4u << 28) | (0xBu << 20) | (7u << 8), 0xFFFFFFFFu };
    uint32_t noteThenBend[] = { noteOn2[0], (0x4u << 28) | (0xEu << 20), 0xFFFFFFFFu };

    struct { const char *name; uint32_t *words; int count; } cases[] = {
        { "type 2 note on", noteOn2, 1 },
        { "type 4 note on at velocity16 0x8000", noteOn4Half, 2 },
        { "type 4 note on at velocity16 0xFFFF", noteOn4Full, 2 },
        { "type 2 note on then type 4 control change 7", noteThenControl, 3 },
        { "type 2 note on then type 4 pitch bend", noteThenBend, 3 },
    };
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++) {
        OSStatus portStatus = 0;
        OSStatus hostStatus = 0;
        NSData *portRender = renderAfterList(CharonTestMusicDeviceMIDIEventList, cases[i].words, cases[i].count, &portStatus);
        NSData *hostRender = renderAfterList(hostList, cases[i].words, cases[i].count, &hostStatus);
        char label[200];
        snprintf(label, sizeof label, "MusicDeviceMIDIEventList, %s: the status is the host's", cases[i].name);
        check(portStatus == hostStatus, label);
        snprintf(label, sizeof label, "MusicDeviceMIDIEventList, %s: the host's render is not silent", cases[i].name);
        check(energy(hostRender) > 0, label);
        snprintf(label, sizeof label, "MusicDeviceMIDIEventList, %s: the render is the host's, bit for bit", cases[i].name);
        check(portRender.length == hostRender.length && memcmp(portRender.bytes, hostRender.bytes, portRender.length) == 0, label);
    }
}

int main(void)
{
    @autoreleasepool {
        checkLastActive();
        printHostIcon();
        checkExtensionLists();
        checkInstantiate();
        checkSoundCompletions();
        checkMIDIList();
        printf("checks=audiotoolbox-functions failures=%d\n", failures);
        return failures == 0 ? 0 : 1;
    }
}
