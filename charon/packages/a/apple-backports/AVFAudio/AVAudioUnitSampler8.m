#import "CharonAVFAudio.h"
#import "CharonAVAudioUnit.h"
#import <AudioToolbox/AudioUnitProperties.h>
#import <AVFAudio/AVAudioUnitSampler.h>

static AudioUnitParameterValue CharonSamplerParameterValue(AudioUnit unit, AudioUnitParameterID identifier)
{
    if (unit == NULL) {
        return 0;
    }
    AudioUnitParameterValue value = 0;
    if (AudioUnitGetParameter(unit, identifier, kAudioUnitScope_Global, 0, &value) != noErr) {
        return 0;
    }
    return value;
}

@implementation AVAudioUnitSampler

static const UInt8 CharonSoundBankType = kInstrumentType_SF2Preset;

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)audioComponentDescription
{
    AudioComponentDescription wanted = audioComponentDescription;
    if (wanted.componentType == 0) {
        wanted.componentType = kAudioUnitType_MusicDevice;
    }
    if (wanted.componentSubType == 0) {
        wanted.componentSubType = kAudioUnitSubType_Sampler;
    }
    if (wanted.componentManufacturer == 0) {
        wanted.componentManufacturer = kAudioUnitManufacturer_Apple;
    }
    return [super initWithCharonComponentDescription:wanted name:nil manufacturerName:nil version:0];
}

- (BOOL)charon_loadInstrumentAtURL:(NSURL *)url
                           program:(uint8_t)program
                            bankMSB:(uint8_t)bankMSB
                            bankLSB:(uint8_t)bankLSB
                             outError:(NSError **)outError
{
    AudioUnit unit = self.audioUnit;
    if (url == nil || unit == NULL) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return NO;
    }
    AUSamplerInstrumentData data;
    memset(&data, 0, sizeof(data));
    data.fileURL = (__bridge CFURLRef)url;
    data.instrumentType = CharonSoundBankType;
    data.bankMSB = bankMSB;
    data.bankLSB = bankLSB;
    data.presetID = program;
    OSStatus status = AudioUnitSetProperty(unit, kAUSamplerProperty_LoadInstrument, kAudioUnitScope_Global,
                                           0, &data, sizeof(data));
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
    return YES;
}

- (BOOL)loadSoundBankInstrumentAtURL:(NSURL *)bankURL
                             program:(uint8_t)program
                              bankMSB:(uint8_t)bankMSB
                              bankLSB:(uint8_t)bankLSB
                               error:(NSError **)outError
{
    return [self charon_loadInstrumentAtURL:bankURL program:program bankMSB:bankMSB bankLSB:bankLSB outError:outError];
}

- (BOOL)loadInstrumentAtURL:(NSURL *)instrumentURL error:(NSError **)outError
{
    return [self charon_loadInstrumentAtURL:instrumentURL program:0 bankMSB:0x79 bankLSB:0x00 outError:outError];
}

- (BOOL)loadAudioFilesAtURLs:(NSArray<NSURL *> *)audioFiles error:(NSError **)outError
{
    if (audioFiles.count == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return NO;
    }
    if (audioFiles.count == 1) {
        return [self loadInstrumentAtURL:audioFiles.firstObject error:outError];
    }
    AudioUnit unit = self.audioUnit;
    if (unit == NULL) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
        }
        return NO;
    }
    NSMutableArray *urls = [NSMutableArray array];
    for (NSURL *url in audioFiles) {
        [urls addObject:url];
    }
    CFArrayRef array = (__bridge_retained CFArrayRef)urls;
    OSStatus status = AudioUnitSetProperty(unit, kAUSamplerProperty_LoadAudioFiles, kAudioUnitScope_Global,
                                           0, &array, sizeof(CFArrayRef));
    CFRelease(array);
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
    return YES;
}

#define CharonSamplerParameter(scope, identifier, value) \
    AudioUnitSetParameter(self.audioUnit, (identifier), (scope), 0, (AudioUnitParameterValue)(value), 0)
#define CharonSamplerParameterRead(identifier) CharonSamplerParameterValue(self.audioUnit, (identifier))

static void CharonSplitTuning(float cents, AudioUnitParameterValue *coarse, AudioUnitParameterValue *fine)
{
    double steps = (double)cents / 100.0;
    double nearest = round(steps);
    if (nearest > 24.0) nearest = 24.0;
    if (nearest < -24.0) nearest = -24.0;
    double remainder = (double)cents - nearest * 100.0;
    if (remainder > 99.0) remainder = 99.0;
    if (remainder < -99.0) remainder = -99.0;
    *coarse = (AudioUnitParameterValue)nearest;
    *fine = (AudioUnitParameterValue)remainder;
}

- (float)globalTuning
{
    AudioUnitParameterValue coarse = CharonSamplerParameterRead(kAUSamplerParam_CoarseTuning);
    AudioUnitParameterValue fine = CharonSamplerParameterRead(kAUSamplerParam_FineTuning);
    if (coarse == 0 && fine == 0) {
        return 0.0f;
    }
    return (float)(coarse * 100.0 + fine);
}

- (void)setGlobalTuning:(float)globalTuning
{
    AudioUnitParameterValue coarse = 0, fine = 0;
    CharonSplitTuning(globalTuning, &coarse, &fine);
    CharonSamplerParameter(kAudioUnitScope_Global, kAUSamplerParam_CoarseTuning, coarse);
    CharonSamplerParameter(kAudioUnitScope_Global, kAUSamplerParam_FineTuning, fine);
}

- (float)masterGain
{
    return (float)CharonSamplerParameterRead(kAUSamplerParam_Gain);
}

- (void)setMasterGain:(float)masterGain
{
    CharonSamplerParameter(kAudioUnitScope_Global, kAUSamplerParam_Gain, masterGain);
}

- (float)overallGain
{
    return (float)CharonSamplerParameterRead(kAUSamplerParam_Gain);
}

- (void)setOverallGain:(float)overallGain
{
    CharonSamplerParameter(kAudioUnitScope_Global, kAUSamplerParam_Gain, overallGain);
}

- (float)stereoPan
{
    return (float)CharonSamplerParameterRead(kAUSamplerParam_Pan);
}

- (void)setStereoPan:(float)stereoPan
{
    CharonSamplerParameter(kAudioUnitScope_Global, kAUSamplerParam_Pan, stereoPan);
}

@end
