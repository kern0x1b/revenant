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
typedef id (*IconFn)(AudioComponent, float);
typedef id (*CopyIconFn)(AudioComponent);
typedef OSStatus (*PublishFn)(const AudioComponentDescription *, CFStringRef, UInt32, AudioUnit);
typedef OSStatus (*BankNameFn)(CFURLRef, CFStringRef *);
typedef OSStatus (*BankInfoFn)(CFURLRef, CFArrayRef *);

CFAbsoluteTime CharonTestAudioComponentGetLastActiveTime(AudioComponent comp);
CFArrayRef CharonTestAudioUnitExtensionCopyComponentList(CFStringRef extensionIdentifier);
OSStatus CharonTestAudioUnitExtensionSetComponentList(CFStringRef extensionIdentifier, CFArrayRef audioComponentInfo);
void CharonTestAudioComponentInstantiate(AudioComponent inComponent, AudioComponentInstantiationOptions inOptions,
                                         void (^inCompletionHandler)(AudioComponentInstance _Nullable, OSStatus));
void CharonTestAudioServicesPlaySystemSoundWithCompletion(SystemSoundID inSystemSoundID, void (^inCompletionBlock)(void));
void CharonTestAudioServicesPlayAlertSoundWithCompletion(SystemSoundID inSystemSoundID, void (^inCompletionBlock)(void));
OSStatus CharonTestMusicDeviceMIDIEventList(MusicDeviceComponent inUnit, UInt32 inOffsetSampleFrame, const MIDIEventList *evtList);
OSStatus CharonTestAudioFileGetUserDataSize64(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, UInt64 *outUserDataSize);
OSStatus CharonTestAudioFileGetUserDataAtOffset(AudioFileID inAudioFile, UInt32 inUserDataID, UInt32 inIndex, SInt64 inOffset,
                                                UInt32 *ioUserDataSize, void *outUserData);
OSStatus CharonTestAudioComponentValidate(AudioComponent inComponent, CFDictionaryRef inValidationParameters,
                                          AudioComponentValidationResult *outValidationResult);
OSStatus CharonTestAudioComponentValidateWithResults(AudioComponent inComponent, CFDictionaryRef inValidationParameters,
                                                     void (^inCompletionBlock)(AudioComponentValidationResult, CFDictionaryRef _Nonnull));
OSStatus CharonTestAudioConverterNewWithOptions(const AudioStreamBasicDescription *inSourceFormat,
                                                const AudioStreamBasicDescription *inDestinationFormat,
                                                AudioConverterOptions inOptions, AudioConverterRef *outAudioConverter);
void CharonTestAudioConverterPrepare(UInt32 inFlags, void *ioReserved, void (^inCompletionBlock)(OSStatus));
OSStatus CharonTestAudioConverterFillComplexBufferRealtimeSafe(AudioConverterRef inAudioConverter,
                                                               AudioConverterComplexInputDataProcRealtimeSafe inInputDataProc,
                                                               void *inInputDataProcUserData, UInt32 *ioOutputDataPacketSize,
                                                               AudioBufferList *outOutputData,
                                                               AudioStreamPacketDescription *outPacketDescription);
OSStatus CharonTestAudioConverterFillComplexBufferWithPacketDependencies(AudioConverterRef inAudioConverter,
                                                                         AudioConverterComplexInputDataProc inInputDataProc,
                                                                         void *inInputDataProcUserData, UInt32 *ioOutputDataPacketSize,
                                                                         AudioBufferList *outOutputData,
                                                                         AudioStreamPacketDescription *outPacketDescriptions,
                                                                         AudioStreamPacketDependencyDescription *outPacketDependencies);
OSStatus CharonTestAudioFileWritePacketsWithDependencies(AudioFileID inAudioFile, Boolean inUseCache, UInt32 inNumBytes,
                                                         const AudioStreamPacketDescription *inPacketDescriptions,
                                                         const AudioStreamPacketDependencyDescription *inPacketDependencies,
                                                         SInt64 inStartingPacket, UInt32 *ioNumPackets, const void *inBuffer);
OSStatus CharonTestAudioQueueNewOutputWithDispatchQueue(AudioQueueRef *outAQ, const AudioStreamBasicDescription *inFormat,
                                                        UInt32 inFlags, dispatch_queue_t inCallbackDispatchQueue,
                                                        AudioQueueOutputCallbackBlock inCallbackBlock);
OSStatus CharonTestAudioQueueNewInputWithDispatchQueue(AudioQueueRef *outAQ, const AudioStreamBasicDescription *inFormat,
                                                       UInt32 inFlags, dispatch_queue_t inCallbackDispatchQueue,
                                                       AudioQueueInputCallbackBlock inCallbackBlock);
OSStatus CharonTestAudioOutputUnitPublish(const AudioComponentDescription *inDesc, CFStringRef inName, UInt32 inVersion,
                                          AudioUnit inOutputUnit);
OSStatus CharonTestCopyNameFromSoundBank(CFURLRef inURL, CFStringRef __nullable *outName);
OSStatus CharonTestCopyInstrumentInfoFromSoundBank(CFURLRef inURL, CFArrayRef __nullable *outInstrumentInfo);

static AudioComponent genericOutput(void)
{
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_GenericOutput;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    return AudioComponentFindNext(NULL, &description);
}

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

static void printHostIcon(void)
{
    HostIconFn hostIcon = hostSymbol("AudioOutputUnitGetHostIcon");
    AudioComponentInstance instance = NULL;
    AudioComponentInstanceNew(genericOutput(), &instance);
    printf("host: AudioOutputUnitGetHostIcon(generic output instance, 32) is %s\n",
           hostIcon((AudioUnit)instance, 32) == nil ? "nil" : "non-nil");
    AudioComponentInstanceDispose(instance);
}

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

    CharonTestAudioServicesPlaySystemSoundWithCompletion(1104, NULL);
    CharonTestAudioServicesPlayAlertSoundWithCompletion(1104, NULL);
    check(1, "AudioServices*WithCompletion: a NULL block plays and returns");
}

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
    uint32_t noteOn2[] = { (0x2u << 28) | (0x90u << 16) | (60u << 8) | 100u };
    uint32_t noteOn4Half[] = { (0x4u << 28) | (0x9u << 20) | (60u << 8), 0x80000000u };
    uint32_t noteOn4Full[] = { (0x4u << 28) | (0x9u << 20) | (60u << 8), 0xFFFF0000u };
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

typedef OSStatus (*Size64Fn)(AudioFileID, UInt32, UInt32, UInt64 *);
typedef OSStatus (*AtOffsetFn)(AudioFileID, UInt32, UInt32, SInt64, UInt32 *, void *);

static AudioFileID makeUserDataFile(const char *folder)
{
    NSString *path = [NSString stringWithFormat:@"%s/userdata.wav", folder];
    NSURL *url = [NSURL fileURLWithPath:path];
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = 44100;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mChannelsPerFrame = 1;
    format.mBitsPerChannel = 16;
    format.mBytesPerFrame = 2;
    format.mBytesPerPacket = 2;
    format.mFramesPerPacket = 1;
    AudioFileID file = NULL;
    if (AudioFileCreateWithURL((__bridge CFURLRef)url, kAudioFileWAVEType, &format, kAudioFileFlags_EraseFile, &file) != noErr) {
        printf("FAIL the user data file cannot be created at %s\n", path.UTF8String);
        exit(1);
    }
    const char data[10] = "0123456789";
    AudioFileSetUserData(file, 'Chrn', 0, 10, data);
    AudioFileClose(file);
    if (AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &file) != noErr) {
        printf("FAIL the user data file cannot be opened\n");
        exit(1);
    }
    return file;
}

static void checkUserData(const char *folder)
{
    AudioFileID file = makeUserDataFile(folder);
    Size64Fn hostSize64 = hostSymbol("AudioFileGetUserDataSize64");
    AtOffsetFn hostAtOffset = hostSymbol("AudioFileGetUserDataAtOffset");

    struct { UInt32 chunk; UInt32 index; } sizeCases[] = { { 'Chrn', 0 }, { 'Chrn', 3 }, { 'none', 0 } };
    for (size_t i = 0; i < sizeof sizeCases / sizeof sizeCases[0]; i++) {
        UInt64 portSize = 777, hostSize = 777;
        OSStatus portStatus = CharonTestAudioFileGetUserDataSize64(file, sizeCases[i].chunk, sizeCases[i].index, &portSize);
        OSStatus hostStatus = hostSize64(file, sizeCases[i].chunk, sizeCases[i].index, &hostSize);
        char label[160];
        snprintf(label, sizeof label, "AudioFileGetUserDataSize64, chunk %u index %u: the status is the host's", sizeCases[i].chunk, sizeCases[i].index);
        check(portStatus == hostStatus, label);
        snprintf(label, sizeof label, "AudioFileGetUserDataSize64, chunk %u index %u: the size is the host's", sizeCases[i].chunk, sizeCases[i].index);
        check(portSize == hostSize, label);
    }

    SInt64 offsets[] = { -1, 0, 2, 6, 8, 10, 12 };
    UInt32 sizes[] = { 0, 4, 32 };
    for (size_t o = 0; o < sizeof offsets / sizeof offsets[0]; o++) {
        for (size_t s = 0; s < sizeof sizes / sizeof sizes[0]; s++) {
            uint8_t portBytes[32], hostBytes[32];
            memset(portBytes, '.', sizeof portBytes);
            memset(hostBytes, '.', sizeof hostBytes);
            UInt32 portIO = sizes[s], hostIO = sizes[s];
            OSStatus portStatus = CharonTestAudioFileGetUserDataAtOffset(file, 'Chrn', 0, offsets[o], &portIO, portBytes);
            OSStatus hostStatus = hostAtOffset(file, 'Chrn', 0, offsets[o], &hostIO, hostBytes);
            char label[200];
            snprintf(label, sizeof label, "AudioFileGetUserDataAtOffset, offset %lld size %u: the status is the host's",
                     offsets[o], sizes[s]);
            check(portStatus == hostStatus, label);
            snprintf(label, sizeof label, "AudioFileGetUserDataAtOffset, offset %lld size %u: the size written is the host's",
                     offsets[o], sizes[s]);
            check(portIO == hostIO, label);
            snprintf(label, sizeof label, "AudioFileGetUserDataAtOffset, offset %lld size %u: the bytes are the host's",
                     offsets[o], sizes[s]);
            check(memcmp(portBytes, hostBytes, sizeof portBytes) == 0, label);
        }
    }
    uint8_t portBytes[4], hostBytes[4];
    UInt32 portIO = 4, hostIO = 4;
    OSStatus portStatus = CharonTestAudioFileGetUserDataAtOffset(file, 'none', 0, 0, &portIO, portBytes);
    OSStatus hostStatus = hostAtOffset(file, 'none', 0, 0, &hostIO, hostBytes);
    check(portStatus == hostStatus && portIO == hostIO,
          "AudioFileGetUserDataAtOffset, a missing chunk: the status and the size are the host's");
    AudioFileClose(file);
}

typedef OSStatus (*ValidateFn)(AudioComponent, CFDictionaryRef, AudioComponentValidationResult *);
typedef OSStatus (*ValidateResultsFn)(AudioComponent, CFDictionaryRef, void (^)(AudioComponentValidationResult, CFDictionaryRef _Nonnull));
typedef OSStatus (*NewWithOptionsFn)(const AudioStreamBasicDescription *, const AudioStreamBasicDescription *, AudioConverterOptions, AudioConverterRef *);
typedef void (*PrepareFn)(UInt32, void *, void (^)(OSStatus));
typedef OSStatus (*RealtimeFillFn)(AudioConverterRef, AudioConverterComplexInputDataProcRealtimeSafe, void *, UInt32 *, AudioBufferList *,
                                   AudioStreamPacketDescription *);
typedef OSStatus (*DependenciesFillFn)(AudioConverterRef, AudioConverterComplexInputDataProc, void *, UInt32 *, AudioBufferList *,
                                       AudioStreamPacketDescription *, AudioStreamPacketDependencyDescription *);
typedef OSStatus (*WriteDependenciesFn)(AudioFileID, Boolean, UInt32, const AudioStreamPacketDescription *,
                                        const AudioStreamPacketDependencyDescription *, SInt64, UInt32 *, const void *);
typedef OSStatus (*FillFn)(AudioConverterRef, AudioConverterComplexInputDataProc, void *, UInt32 *, AudioBufferList *,
                           AudioStreamPacketDescription *);
typedef OSStatus (*QueueOutputFn)(AudioQueueRef *, const AudioStreamBasicDescription *, UInt32, dispatch_queue_t, AudioQueueOutputCallbackBlock);

static void checkValidate(void)
{
    ValidateFn hostValidate = hostSymbol("AudioComponentValidate");
    ValidateResultsFn hostValidateResults = hostSymbol("AudioComponentValidateWithResults");
    AudioComponentValidationResult portResult = 0, hostResult = 0;
    OSStatus portStatus = CharonTestAudioComponentValidate(genericOutput(), NULL, &portResult);
    OSStatus hostStatus = hostValidate(genericOutput(), NULL, &hostResult);
    check(portStatus == hostStatus && portResult == hostResult,
          "AudioComponentValidate, the generic output: the status and the result are the host's");
    check(hostResult == kAudioComponentValidationResult_Passed, "AudioComponentValidate, the generic output: the host passes it");

    AudioComponentValidationResult unusedPort = 0, unusedHost = 0;
    check(CharonTestAudioComponentValidate(NULL, NULL, &unusedPort) == hostValidate(NULL, NULL, &unusedHost),
          "AudioComponentValidate, a NULL component: the status is the host's");

    for (int side = 0; side < 2; side++) {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block AudioComponentValidationResult result = 0;
        __block BOOL onMain = YES;
        __block NSNumber *dictionaryResult = nil;
        void (^completion)(AudioComponentValidationResult, CFDictionaryRef _Nonnull) = ^(AudioComponentValidationResult r, CFDictionaryRef dict) {
            result = r;
            onMain = pthread_main_np();
            dictionaryResult = ((__bridge NSDictionary *)dict)[@"Result"];
            dispatch_semaphore_signal(done);
        };
        OSStatus status = side == 0 ? CharonTestAudioComponentValidateWithResults(genericOutput(), NULL, completion)
                                    : hostValidateResults(genericOutput(), NULL, completion);
        BOOL fired = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
        char label[160];
        snprintf(label, sizeof label, "%s AudioComponentValidateWithResults, the generic output: the block runs once, off the main thread",
                 side == 0 ? "port" : "host");
        check(status == noErr && fired && !onMain, label);
        snprintf(label, sizeof label, "%s AudioComponentValidateWithResults, the generic output: passed, and the dictionary's Result is passed",
                 side == 0 ? "port" : "host");
        check(fired && result == kAudioComponentValidationResult_Passed && dictionaryResult.intValue == kAudioComponentValidationResult_Passed, label);
    }
}

typedef struct {
    int given;
    float samples[64];
    UInt32 frames;
} ConverterInput;

static void resetInput(ConverterInput *input, UInt32 frames)
{
    memset(input, 0, sizeof *input);
    input->frames = frames;
    for (UInt32 i = 0; i < frames; i++) {
        input->samples[i] = (float)i / 8.0f - 0.5f;
    }
}

static OSStatus supplyConverterInput(AudioConverterRef converter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,
                                     AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    ConverterInput *input = inUserData;
    if (input->given) {
        *ioNumberDataPackets = 0;
        ioData->mBuffers[0].mDataByteSize = 0;
        return noErr;
    }
    input->given = 1;
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData = input->samples;
    ioData->mBuffers[0].mDataByteSize = input->frames * sizeof(float);
    *ioNumberDataPackets = input->frames;
    return noErr;
}

static OSStatus supplyConverterInputRealtime(AudioConverterRef converter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,
                                             AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    return supplyConverterInput(converter, ioNumberDataPackets, ioData, outDataPacketDescription, inUserData);
}

static void checkConverters(void)
{
    NewWithOptionsFn hostNew = hostSymbol("AudioConverterNewWithOptions");
    PrepareFn hostPrepare = hostSymbol("AudioConverterPrepare");
    RealtimeFillFn hostRealtime = hostSymbol("AudioConverterFillComplexBufferRealtimeSafe");
    DependenciesFillFn hostDependencies = hostSymbol("AudioConverterFillComplexBufferWithPacketDependencies");
    FillFn hostFill = hostSymbol("AudioConverterFillComplexBuffer");

    AudioStreamBasicDescription source = {0}, destination = {0}, alac = {0};
    source.mSampleRate = 44100;
    source.mFormatID = kAudioFormatLinearPCM;
    source.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    source.mChannelsPerFrame = 1;
    source.mBitsPerChannel = 32;
    source.mBytesPerFrame = 4;
    source.mBytesPerPacket = 4;
    source.mFramesPerPacket = 1;
    destination = source;
    destination.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    destination.mBitsPerChannel = 16;
    destination.mBytesPerFrame = 2;
    destination.mBytesPerPacket = 2;
    alac.mSampleRate = 44100;
    alac.mFormatID = kAudioFormatAppleLossless;
    alac.mChannelsPerFrame = 1;
    alac.mFramesPerPacket = 4096;

    AudioConverterRef portConverter = NULL, hostConverter = NULL;
    OSStatus portNew = CharonTestAudioConverterNewWithOptions(&source, &destination, 0, &portConverter);
    OSStatus hostNewStatus = hostNew(&source, &destination, 0, &hostConverter);
    check(portNew == hostNewStatus && portConverter != NULL && hostConverter != NULL,
          "AudioConverterNewWithOptions, no options: the status is the host's and a converter is made");

    ConverterInput portInput, hostInput;
    SInt16 portOut[16], hostOut[16];
    resetInput(&portInput, 8);
    resetInput(&hostInput, 8);
    memset(portOut, 0, sizeof portOut);
    memset(hostOut, 0, sizeof hostOut);
    AudioBufferList portList = { 1, { { 1, sizeof portOut, portOut } } };
    AudioBufferList hostList = { 1, { { 1, sizeof hostOut, hostOut } } };
    UInt32 portPackets = 8, hostPackets = 8;
    OSStatus portFill = AudioConverterFillComplexBuffer(portConverter, supplyConverterInput, &portInput, &portPackets, &portList, NULL);
    OSStatus hostFillStatus = hostFill(hostConverter, supplyConverterInput, &hostInput, &hostPackets, &hostList, NULL);
    check(portFill == hostFillStatus && portPackets == hostPackets && memcmp(portOut, hostOut, sizeof portOut) == 0,
          "the port's converter converts as the host's does, bit for bit");

    AudioConverterRef unbufferedPort = NULL, unbufferedHost = NULL;
    OSStatus unbufferedPortStatus = CharonTestAudioConverterNewWithOptions(&source, &destination, kAudioConverterOption_Unbuffered, &unbufferedPort);
    OSStatus unbufferedHostStatus = hostNew(&source, &destination, kAudioConverterOption_Unbuffered, &unbufferedHost);
    check(unbufferedPortStatus == unbufferedHostStatus, "AudioConverterNewWithOptions, the unbuffered option: the status is the host's");
    ConverterInput unbufferedInput;
    resetInput(&unbufferedInput, 8);
    UInt32 unbufferedPackets = 8;
    OSStatus unbufferedFill = hostFill(unbufferedHost, supplyConverterInput, &unbufferedInput, &unbufferedPackets, &hostList, NULL);
    printf("host: AudioConverterFillComplexBuffer on the unbuffered converter is %d (the port's converter is buffered)\n", (int)unbufferedFill);

    for (int side = 0; side < 2; side++) {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block OSStatus status = -1;
        __block BOOL onMain = YES;
        void (^completion)(OSStatus) = ^(OSStatus s) {
            status = s;
            onMain = pthread_main_np();
            dispatch_semaphore_signal(done);
        };
        if (side == 0) {
            CharonTestAudioConverterPrepare(0, NULL, completion);
        } else {
            hostPrepare(0, NULL, completion);
        }
        BOOL fired = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
        char label[160];
        snprintf(label, sizeof label, "%s AudioConverterPrepare: the completion runs once with noErr, off the main thread",
                 side == 0 ? "port" : "host");
        check(fired && status == noErr && !onMain, label);
    }

    ConverterInput portRealtimeInput, hostRealtimeInput;
    resetInput(&portRealtimeInput, 8);
    resetInput(&hostRealtimeInput, 8);
    memset(portOut, 0, sizeof portOut);
    memset(hostOut, 0, sizeof hostOut);
    portPackets = 8;
    hostPackets = 8;
    AudioBufferList portRealtimeList = { 1, { { 1, sizeof portOut, portOut } } };
    AudioBufferList hostRealtimeList = { 1, { { 1, sizeof hostOut, hostOut } } };
    OSStatus portRealtime = CharonTestAudioConverterFillComplexBufferRealtimeSafe(portConverter, supplyConverterInputRealtime, &portRealtimeInput,
                                                                                  &portPackets, &portRealtimeList, NULL);
    OSStatus hostRealtimeStatus = hostRealtime(hostConverter, supplyConverterInputRealtime, &hostRealtimeInput, &hostPackets, &hostRealtimeList, NULL);
    check(portRealtime == hostRealtimeStatus && portRealtime == noErr && memcmp(portOut, hostOut, sizeof portOut) == 0,
          "AudioConverterFillComplexBufferRealtimeSafe, PCM to PCM: the status and the output are the host's, bit for bit");

    AudioConverterRef portEncoder = NULL, hostEncoder = NULL;
    OSStatus portEncoderStatus = CharonTestAudioConverterNewWithOptions(&source, &alac, 0, &portEncoder);
    OSStatus hostEncoderStatus = hostNew(&source, &alac, 0, &hostEncoder);
    check(portEncoderStatus == hostEncoderStatus, "AudioConverterNewWithOptions, PCM to ALAC: the status is the host's");
    UInt8 portBytes[65536], hostBytes[65536];
    AudioStreamPacketDescription portDescriptions[1], hostDescriptions[1];
    AudioBufferList portEncoded = { 1, { { 1, sizeof portBytes, portBytes } } };
    AudioBufferList hostEncoded = { 1, { { 1, sizeof hostBytes, hostBytes } } };
    ConverterInput portEncodeInput, hostEncodeInput;
    resetInput(&portEncodeInput, 8);
    resetInput(&hostEncodeInput, 8);
    UInt32 portEncodedPackets = 1, hostEncodedPackets = 1;
    OSStatus portEncode = CharonTestAudioConverterFillComplexBufferRealtimeSafe(portEncoder, supplyConverterInputRealtime, &portEncodeInput,
                                                                                &portEncodedPackets, &portEncoded, portDescriptions);
    OSStatus hostEncode = hostRealtime(hostEncoder, supplyConverterInputRealtime, &hostEncodeInput, &hostEncodedPackets, &hostEncoded, hostDescriptions);
    check(portEncode == hostEncode && portEncode == kAudioConverterErr_OperationNotSupported,
          "AudioConverterFillComplexBufferRealtimeSafe, PCM to ALAC: refused with kAudioConverterErr_OperationNotSupported, as the host refuses");

    ConverterInput portDependencyInput, hostDependencyInput;
    resetInput(&portDependencyInput, 8);
    resetInput(&hostDependencyInput, 8);
    memset(portOut, 0, sizeof portOut);
    memset(hostOut, 0, sizeof hostOut);
    portPackets = 8;
    hostPackets = 8;
    AudioBufferList portDependencyList = { 1, { { 1, sizeof portOut, portOut } } };
    AudioBufferList hostDependencyList = { 1, { { 1, sizeof hostOut, hostOut } } };
    AudioStreamPacketDependencyDescription portDeps[8], hostDeps[8];
    AudioStreamPacketDescription descriptions[8];
    memset(portDeps, 0x5A, sizeof portDeps);
    memset(hostDeps, 0x5A, sizeof hostDeps);
    OSStatus portDependencies = CharonTestAudioConverterFillComplexBufferWithPacketDependencies(portConverter, supplyConverterInput, &portDependencyInput,
                                                                                                &portPackets, &portDependencyList, descriptions, portDeps);
    OSStatus hostDependenciesStatus = hostDependencies(hostConverter, supplyConverterInput, &hostDependencyInput, &hostPackets, &hostDependencyList,
                                                       descriptions, hostDeps);
    check(portDependencies == hostDependenciesStatus && portDependencies == noErr && memcmp(portOut, hostOut, sizeof portOut) == 0,
          "AudioConverterFillComplexBufferWithPacketDependencies, PCM: the status and the output are the host's, bit for bit");
    check(portDeps[0].mIsIndependentlyDecodable == 0x5A5A5A5A && hostDeps[0].mIsIndependentlyDecodable == 0x5A5A5A5A,
          "AudioConverterFillComplexBufferWithPacketDependencies, PCM: the dependencies are left as they were, on both sides");
    ConverterInput portNullInput, hostNullInput;
    resetInput(&portNullInput, 8);
    resetInput(&hostNullInput, 8);
    UInt32 portNullPackets = 8, hostNullPackets = 8;
    OSStatus portNull = CharonTestAudioConverterFillComplexBufferWithPacketDependencies(portConverter, supplyConverterInput, &portNullInput,
                                                                                        &portNullPackets, &portDependencyList, NULL, portDeps);
    OSStatus hostNull = hostDependencies(hostConverter, supplyConverterInput, &hostNullInput, &hostNullPackets, &hostDependencyList, NULL, hostDeps);
    check(portNull == hostNull && portNull == kAudio_ParamError,
          "AudioConverterFillComplexBufferWithPacketDependencies, NULL descriptions: -50 on both sides");

    AudioConverterDispose(portConverter);
    AudioConverterDispose(hostConverter);
    AudioConverterDispose(unbufferedHost);
    AudioConverterDispose(portEncoder);
    AudioConverterDispose(hostEncoder);
}

static void checkFileDependencies(const char *folder)
{
    WriteDependenciesFn hostWrite = hostSymbol("AudioFileWritePacketsWithDependencies");
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = 44100;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mChannelsPerFrame = 1;
    format.mBitsPerChannel = 16;
    format.mBytesPerFrame = 2;
    format.mBytesPerPacket = 2;
    format.mFramesPerPacket = 1;
    SInt16 samples[4] = { 1, 2, 3, 4 };
    AudioStreamPacketDependencyDescription dependencies[4];
    memset(dependencies, 0, sizeof dependencies);
    for (int side = 0; side < 2; side++) {
        for (int withDependencies = 0; withDependencies < 2; withDependencies++) {
            NSString *path = [NSString stringWithFormat:@"%s/dependencies-%d-%d.wav", folder, side, withDependencies];
            AudioFileID file = NULL;
            if (AudioFileCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], kAudioFileWAVEType, &format, kAudioFileFlags_EraseFile, &file) != noErr) {
                printf("FAIL the dependency file cannot be created at %s\n", path.UTF8String);
                exit(1);
            }
            UInt32 packets = 4;
            const AudioStreamPacketDependencyDescription *deps = withDependencies ? dependencies : NULL;
            OSStatus status = side == 0 ? CharonTestAudioFileWritePacketsWithDependencies(file, false, 8, NULL, deps, 0, &packets, samples)
                                        : hostWrite(file, false, 8, NULL, deps, 0, &packets, samples);
            AudioFileClose(file);
            char label[200];
            snprintf(label, sizeof label, "%s AudioFileWritePacketsWithDependencies, dependencies %s: the status and the packets are the host's",
                     side == 0 ? "port" : "host", withDependencies ? "given" : "NULL");
            check(status == noErr && packets == 4, label);
        }
    }
}

static void checkQueueDispatch(void)
{
    QueueOutputFn hostOutput = hostSymbol("AudioQueueNewOutputWithDispatchQueue");
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = 44100;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mChannelsPerFrame = 1;
    format.mBitsPerChannel = 16;
    format.mBytesPerFrame = 2;
    format.mBytesPerPacket = 2;
    format.mFramesPerPacket = 1;
    AudioQueueRef nullPort = NULL, nullHost = NULL;
    check(CharonTestAudioQueueNewOutputWithDispatchQueue(&nullPort, &format, 0, NULL, ^(AudioQueueRef q, AudioQueueBufferRef b) {})
          == hostOutput(&nullHost, &format, 0, NULL, ^(AudioQueueRef q, AudioQueueBufferRef b) {}),
          "AudioQueueNewOutputWithDispatchQueue, a NULL queue: the status is the host's");

    for (int side = 0; side < 2; side++) {
        dispatch_queue_t queue = dispatch_queue_create("charon.functions.queue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(queue, (__bridge const void *)queue, (void *)1, NULL);
        dispatch_semaphore_t played = dispatch_semaphore_create(0);
        __block BOOL onQueue = NO;
        __block BOOL onMain = YES;
        AudioQueueOutputCallbackBlock block = ^(AudioQueueRef q, AudioQueueBufferRef b) {
            onQueue = dispatch_get_specific((__bridge const void *)queue) != NULL;
            onMain = pthread_main_np();
            dispatch_semaphore_signal(played);
        };
        AudioQueueRef aq = NULL;
        OSStatus status = side == 0 ? CharonTestAudioQueueNewOutputWithDispatchQueue(&aq, &format, 0, queue, block)
                                    : hostOutput(&aq, &format, 0, queue, block);
        check(status == noErr, side == 0 ? "port AudioQueueNewOutputWithDispatchQueue: noErr" : "host AudioQueueNewOutputWithDispatchQueue: noErr (oracle)");
        if (status == noErr) {
            AudioQueueBufferRef buffer = NULL;
            AudioQueueAllocateBuffer(aq, 2048, &buffer);
            memset(buffer->mAudioData, 0, 2048);
            buffer->mAudioDataByteSize = 2048;
            AudioQueueEnqueueBuffer(aq, buffer, 0, NULL);
            AudioQueueStart(aq, NULL);
            BOOL fired = dispatch_semaphore_wait(played, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0;
            AudioQueueStop(aq, true);
            AudioQueueDispose(aq, true);
            char label[200];
            snprintf(label, sizeof label, "%s AudioQueueNewOutputWithDispatchQueue: the block runs on the queue it was given",
                     side == 0 ? "port" : "host");
            check(fired && onQueue, label);
            snprintf(label, sizeof label, "%s AudioQueueNewOutputWithDispatchQueue: the block runs off the main thread",
                     side == 0 ? "port" : "host");
            check(fired && !onMain, label);
        }
    }
}

static void releaseCF(CFTypeRef ref)
{
    if (ref != NULL) {
        CFRelease(ref);
    }
}

static void printIcons(void)
{
    IconFn hostGetIcon = hostSymbol("AudioComponentGetIcon");
    CopyIconFn hostCopyIcon = hostSymbol("AudioComponentCopyIcon");
    AudioComponent component = genericOutput();
    float sizes[] = {0, 16, 32, 64, 128};
    for (int i = 0; i < 5; i++) {
        id icon = hostGetIcon(component, sizes[i]);
        NSSize size = icon == nil ? NSZeroSize : [[(NSObject *)icon valueForKey:@"size"] sizeValue];
        printf("host: AudioComponentGetIcon(generic output, %g) is %s, %gx%g\n", sizes[i], icon == nil ? "nil" : "an image",
               size.width, size.height);
    }
    id copied = hostCopyIcon(component);
    printf("host: AudioComponentCopyIcon(generic output) is %s\n", copied == nil ? "nil" : "an image");
    printf("host: AudioComponentGetIcon(NULL, 32) is %s\n", hostGetIcon(NULL, 32) == nil ? "nil" : "an image");
    printf("host: AudioComponentCopyIcon(NULL) is %s\n", hostCopyIcon(NULL) == nil ? "nil" : "an image");
}

static void checkPublish(void)
{
    PublishFn hostPublish = hostSymbol("AudioOutputUnitPublish");
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = 'chrn';
    description.componentManufacturer = 'Chrn';
    AudioComponentInstance instance = NULL;
    AudioComponentInstanceNew(genericOutput(), &instance);
    AudioUnit unit = (AudioUnit)instance;
    CFStringRef name = CFSTR("Charon test publication");

    check(CharonTestAudioOutputUnitPublish(&description, name, 1, unit) == hostPublish(&description, name, 1, unit),
          "AudioOutputUnitPublish: the port's answer is the host's for a description and a unit");
    check(CharonTestAudioOutputUnitPublish(&description, name, 1, NULL) == hostPublish(&description, name, 1, NULL),
          "AudioOutputUnitPublish: the port's answer is the host's for a NULL unit");
    check(CharonTestAudioOutputUnitPublish(&description, NULL, 1, unit) == hostPublish(&description, NULL, 1, unit),
          "AudioOutputUnitPublish: the port's answer is the host's for a NULL name");
    check(CharonTestAudioOutputUnitPublish(&description, name, 0, unit) == hostPublish(&description, name, 0, unit),
          "AudioOutputUnitPublish: the port's answer is the host's for version 0");
    check(CharonTestAudioOutputUnitPublish(NULL, name, 1, unit) == hostPublish(NULL, name, 1, unit),
          "AudioOutputUnitPublish: the port's answer is the host's for a NULL description");
    printf("host: AudioComponentFindNext for the published description is %s\n",
           AudioComponentFindNext(NULL, &description) == NULL ? "NULL" : "a component");
    AudioComponentInstanceDispose(instance);
}

static void checkSoundBanks(const char *folder)
{
    static const char *gmBank = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls";
    BankNameFn hostName = hostSymbol("CopyNameFromSoundBank");
    BankInfoFn hostInfo = hostSymbol("CopyInstrumentInfoFromSoundBank");
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *dir = [NSString stringWithUTF8String:folder];
    NSData *bankBytes = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:gmBank]];
    if (bankBytes == nil) {
        printf("FAIL the host has no %s\n", gmBank);
        exit(1);
    }

    CFURLRef bank = (__bridge CFURLRef)[NSURL fileURLWithPath:[NSString stringWithUTF8String:gmBank]];
    CFStringRef hostNameValue = NULL;
    CFStringRef portNameValue = NULL;
    OSStatus hostNameStatus = hostName(bank, &hostNameValue);
    OSStatus portNameStatus = CharonTestCopyNameFromSoundBank(bank, &portNameValue);
    check(hostNameStatus == 0 && portNameStatus == hostNameStatus,
          "CopyNameFromSoundBank: the port's status is the host's for gs_instruments.dls");
    check(hostNameValue != NULL && portNameValue != NULL &&
          [(__bridge NSString *)hostNameValue isEqualToString:(__bridge NSString *)portNameValue],
          "CopyNameFromSoundBank: the port's name is the host's for gs_instruments.dls");
    printf("host: CopyNameFromSoundBank(gs_instruments.dls) is %s\n", hostNameValue ? [(__bridge NSString *)hostNameValue UTF8String] : "NULL");
    releaseCF(hostNameValue);
    releaseCF(portNameValue);

    CFArrayRef hostList = NULL;
    CFArrayRef portList = NULL;
    OSStatus hostListStatus = hostInfo(bank, &hostList);
    OSStatus portListStatus = CharonTestCopyInstrumentInfoFromSoundBank(bank, &portList);
    NSArray *hostArray = (__bridge NSArray *)hostList;
    NSArray *portArray = (__bridge NSArray *)portList;
    check(hostListStatus == 0 && portListStatus == hostListStatus,
          "CopyInstrumentInfoFromSoundBank: the port's status is the host's for gs_instruments.dls");
    check(hostArray != nil && [portArray isEqualToArray:hostArray],
          "CopyInstrumentInfoFromSoundBank: the port's 235 entries are the host's for gs_instruments.dls");
    printf("host: CopyInstrumentInfoFromSoundBank(gs_instruments.dls) status %d, %lu entries\n", (int)hostListStatus,
           (unsigned long)hostArray.count);
    releaseCF(hostList);
    releaseCF(portList);

    NSString *sf2Path = [dir stringByAppendingPathComponent:@"copy.sf2"];
    [bankBytes writeToFile:sf2Path atomically:NO];
    CFURLRef sf2 = (__bridge CFURLRef)[NSURL fileURLWithPath:sf2Path];
    CFArrayRef hostSf2List = NULL;
    CFArrayRef portSf2List = NULL;
    OSStatus hostSf2Status = hostInfo(sf2, &hostSf2List);
    OSStatus portSf2Status = CharonTestCopyInstrumentInfoFromSoundBank(sf2, &portSf2List);
    check(hostSf2Status == 0 && portSf2Status == hostSf2Status &&
          [(__bridge NSArray *)portSf2List isEqualToArray:(__bridge NSArray *)hostSf2List],
          "CopyInstrumentInfoFromSoundBank: the port reads a DLS bank named .sf2 as the host does");
    releaseCF(hostSf2List);
    releaseCF(portSf2List);

    CFURLRef missing = (__bridge CFURLRef)[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"absent.dls"]];
    CFStringRef hostMissingName = NULL;
    CFStringRef portMissingName = NULL;
    OSStatus hostMissingStatus = hostName(missing, &hostMissingName);
    OSStatus portMissingStatus = CharonTestCopyNameFromSoundBank(missing, &portMissingName);
    check(hostMissingStatus == -10871 && portMissingStatus == hostMissingStatus,
          "CopyNameFromSoundBank: a missing file's status is the host's");
    check(hostMissingName != NULL && portMissingName != NULL &&
          [(__bridge NSString *)hostMissingName isEqualToString:(__bridge NSString *)portMissingName],
          "CopyNameFromSoundBank: a missing file's name is the host's last path component");
    releaseCF(hostMissingName);
    releaseCF(portMissingName);
    CFArrayRef hostMissingList = NULL;
    CFArrayRef portMissingList = NULL;
    OSStatus hostMissingListStatus = hostInfo(missing, &hostMissingList);
    OSStatus portMissingListStatus = CharonTestCopyInstrumentInfoFromSoundBank(missing, &portMissingList);
    check(hostMissingListStatus == -43 && portMissingListStatus == hostMissingListStatus,
          "CopyInstrumentInfoFromSoundBank: a missing file's status is the host's (fnfErr)");

    NSString *directory = [dir stringByAppendingPathComponent:@"bankdir.dls"];
    [files createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    CFURLRef dirURL = (__bridge CFURLRef)[NSURL fileURLWithPath:directory];
    CFStringRef hostDirName = NULL;
    CFStringRef portDirName = NULL;
    OSStatus hostDirStatus = hostName(dirURL, &hostDirName);
    OSStatus portDirStatus = CharonTestCopyNameFromSoundBank(dirURL, &portDirName);
    check(hostDirStatus == -10871 && portDirStatus == hostDirStatus,
          "CopyNameFromSoundBank: a directory's status is the host's");
    releaseCF(hostDirName);
    releaseCF(portDirName);
    CFArrayRef hostDirList = NULL;
    CFArrayRef portDirList = NULL;
    OSStatus hostDirListStatus = hostInfo(dirURL, &hostDirList);
    OSStatus portDirListStatus = CharonTestCopyInstrumentInfoFromSoundBank(dirURL, &portDirList);
    check(hostDirListStatus == -10871 && portDirListStatus == hostDirListStatus,
          "CopyInstrumentInfoFromSoundBank: a directory's status is the host's");

    NSString *textPath = [dir stringByAppendingPathComponent:@"notabank.dls"];
    [[@"not a bank\n" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:textPath atomically:NO];
    CFURLRef text = (__bridge CFURLRef)[NSURL fileURLWithPath:textPath];
    CFArrayRef portTextList = NULL;
    OSStatus portTextStatus = CharonTestCopyInstrumentInfoFromSoundBank(text, &portTextList);
    check(portTextStatus == -10871, "CopyInstrumentInfoFromSoundBank: a text file is kAudioUnitErr_InvalidFile, as the host answers");

    NSString *truncatedPath = [dir stringByAppendingPathComponent:@"truncated.dls"];
    [[bankBytes subdataWithRange:NSMakeRange(0, 100)] writeToFile:truncatedPath atomically:NO];
    CFURLRef truncated = (__bridge CFURLRef)[NSURL fileURLWithPath:truncatedPath];
    CFArrayRef hostTruncatedList = NULL;
    CFArrayRef portTruncatedList = NULL;
    OSStatus hostTruncatedStatus = hostInfo(truncated, &hostTruncatedList);
    OSStatus portTruncatedStatus = CharonTestCopyInstrumentInfoFromSoundBank(truncated, &portTruncatedList);
    printf("host: CopyInstrumentInfoFromSoundBank(first 100 bytes) status %d, %lu entries; port status %d, %lu entries (not counted)\n",
           (int)hostTruncatedStatus, (unsigned long)[(__bridge NSArray *)hostTruncatedList count], (int)portTruncatedStatus,
           (unsigned long)[(__bridge NSArray *)portTruncatedList count]);
    releaseCF(hostTruncatedList);
    releaseCF(portTruncatedList);
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 2) {
            printf("usage: functions <a folder for the files this test writes>\n");
            return 2;
        }
        checkLastActive();
        printHostIcon();
        checkExtensionLists();
        checkInstantiate();
        checkSoundCompletions();
        checkMIDIList();
        printIcons();
        checkPublish();
        checkSoundBanks(argv[1]);
        checkUserData(argv[1]);
        checkValidate();
        checkConverters();
        checkFileDependencies(argv[1]);
        checkQueueDispatch();
        printf("checks=audiotoolbox-functions failures=%d\n", failures);
        return failures == 0 ? 0 : 1;
    }
}
