#import "CharonAVFAudio.h"
#import "CharonAVAudioUnit.h"
#import <AudioToolbox/AudioUnitProperties.h>
#import <AVFAudio/AVAudioUnitSampler.h>

// AVAudioUnitSampler, over the release's own sampler - which the emulator probe found registered on
// iOS 6.1.3, and which is what this file is built on.
//
// The load is the release's own property: kAUSamplerProperty_LoadInstrument, Scope Global, Value
// Type AUSamplerInstrumentData, Access Write (AudioUnitProperties.h:3636 and :3651). That struct is
// a file URL, an instrument type, a bank MSB, a bank LSB and a preset ID - the same five things the
// header's method takes, in the release's own layout. kAUSamplerProperty_LoadAudioFiles (:3639,
// :3652) takes a CFArrayRef and is how a list of audio files is loaded.
//
// What is not carried is the note-control half of the header: startNote:velocity:channel:,
// stopNote:channel:, reset and the rest are declared by AVFAudioUnitMIDIInstrument's family and need
// the sampler's own instrument interface, which the release's property set does not name. The load is
// real and complete; the notes are not, and the facts file says which is which.

// One read, so a unit this port could not instantiate answers zero rather than an invented value.
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

// The instrument types the load property takes, from the header's own InstrumentTypes enumeration:
// kInstrumentType_DLSPreset, kInstrumentType_SF2Preset, kInstrumentType_AUPreset and
// kInstrumentType_Audiofile. A sound bank is an SF2, so that is what a sound-bank load asks for, and
// an audio file is the one kAUSamplerProperty_LoadAudioFiles covers.
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

// The release's load, through the release's struct. Everything the method can say, it says from the
// status: a file the release will not load is reported as an error with that status, not as a load
// that quietly did nothing.
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
    // The full bank range, which is what a caller naming one instrument without a bank means: MSB
    // 0x79 and LSB 0x00 is the all-banks pair, and it is the release's own convention rather than a
    // value this port chose.
    return [self charon_loadInstrumentAtURL:instrumentURL program:0 bankMSB:0x79 bankLSB:0x00 outError:outError];
}

// A list of audio files is the release's own second load property, kAUSamplerProperty_LoadAudioFiles,
// whose value is a CFArrayRef. One file is that array of one; an empty list is refused rather than
// answered as a load of nothing.
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

// The four members the release's own sampler carries. The ids and the ranges are not guessed: the
// host's AVAudioUnitSampler was asked, and the values below are its answers -
//
//   kAUSamplerParam_Gain         900   range -96 .. 12    decibels, one to one
//   kAUSamplerParam_CoarseTuning 901   range -24 .. 24    the coarse one: units of 100 cents
//   kAUSamplerParam_FineTuning   902   range -99 .. 99    the remainder the coarse one leaves
//   kAUSamplerParam_Pan          903   range -100 .. 100  the unit's own pan scale
//
// AVFAudio's globalTuning is documented in cents, -2400 .. +2400, against a coarse parameter of -24 ..
// 24 - a factor of a hundred - which is what makes that parameter the coarse one and _FineTuning the
// remainder. facts/AVFAudio/AVAudioUnitSampler.md has the host's own output.
#define CharonSamplerParameter(scope, identifier, value) \
    AudioUnitSetParameter(self.audioUnit, (identifier), (scope), 0, (AudioUnitParameterValue)(value), 0)
#define CharonSamplerParameterRead(identifier) CharonSamplerParameterValue(self.audioUnit, (identifier))

// AVFAudio's globalTuning, in cents, and the release's two tuning parameters. A value of a hundred
// cents and above is the coarse parameter; below that is the remainder the coarse one cannot hold,
// which is why the two exist and why _FineTuning's range is +/-99 and not +/-100.
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
