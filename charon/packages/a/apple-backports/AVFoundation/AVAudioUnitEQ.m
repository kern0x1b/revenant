#import "CharonAVAudioUnit.h"

// Real AUNBandEQ parameter layout (AudioToolbox/AudioUnitParameters.h): kAUNBandEQParam_GlobalGain
// has no band, every other parameter ID is band 0's ID plus the zero-indexed band number.
// kAUNBandEQProperty_NumberOfBands (2200) must be set before the audio unit is initialized - this
// port's AVAudioEngine always attaches a node (AUGraphAddNode, no AUGraphInitialize yet) before the
// graph as a whole is initialized in -prepare, so -charon_applyPendingParameters always lands
// before that point, exactly like a real caller configuring bands right after -initWithNumberOfBands:
// and before -attachNode:.
static const AudioUnitPropertyID kCharonNBandEQNumberOfBands = 2200;

@implementation AVAudioUnitEQFilterParameters {
    __weak AVAudioUnitEQ *_charon_eq;
    NSUInteger _charon_bandIndex;
    AVAudioUnitEQFilterType _filterType;
    float _frequency;
    float _bandwidth;
    float _gain;
    BOOL _bypass;
}

- (instancetype)initForCharonEQ:(AVAudioUnitEQ *)eq bandIndex:(NSUInteger)bandIndex
{
    if ((self = [super init])) {
        _charon_eq = eq;
        _charon_bandIndex = bandIndex;
        _filterType = AVAudioUnitEQFilterTypeParametric;
        _frequency = 1000;
        _bandwidth = 0.5;
        _gain = 0;
        _bypass = YES;   // matches Apple's own documented default: a fresh band does nothing
    }
    return self;
}

- (AVAudioUnitEQFilterType)filterType
{
    return _filterType;
}

- (void)setFilterType:(AVAudioUnitEQFilterType)filterType
{
    _filterType = filterType;
    [_charon_eq charon_setParameterID:kAUNBandEQParam_FilterType bandIndex:_charon_bandIndex value:(AudioUnitParameterValue)filterType];
}

- (float)frequency
{
    return _frequency;
}

- (void)setFrequency:(float)frequency
{
    _frequency = frequency;
    [_charon_eq charon_setParameterID:kAUNBandEQParam_Frequency bandIndex:_charon_bandIndex value:frequency];
}

- (float)bandwidth
{
    return _bandwidth;
}

- (void)setBandwidth:(float)bandwidth
{
    _bandwidth = bandwidth;
    [_charon_eq charon_setParameterID:kAUNBandEQParam_Bandwidth bandIndex:_charon_bandIndex value:bandwidth];
}

- (float)gain
{
    return _gain;
}

- (void)setGain:(float)gain
{
    _gain = gain;
    [_charon_eq charon_setParameterID:kAUNBandEQParam_Gain bandIndex:_charon_bandIndex value:gain];
}

- (BOOL)bypass
{
    return _bypass;
}

- (void)setBypass:(BOOL)bypass
{
    _bypass = bypass;
    [_charon_eq charon_setParameterID:kAUNBandEQParam_BypassBand bandIndex:_charon_bandIndex value:bypass ? 1 : 0];
}

@end

@implementation AVAudioUnitEQ {
    NSArray<AVAudioUnitEQFilterParameters *> *_charon_bands;
    float _charon_globalGain;
}

- (instancetype)initWithNumberOfBands:(NSUInteger)numberOfBands
{
    AudioComponentDescription desc = {
        .componentType = kAudioUnitType_Effect,
        .componentSubType = kAudioUnitSubType_NBandEQ,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
    };
    if ((self = [self initWithCharonComponentDescription:desc name:@"AUNBandEQ" manufacturerName:@"Apple" version:0])) {
        NSMutableArray<AVAudioUnitEQFilterParameters *> *bands = [NSMutableArray arrayWithCapacity:numberOfBands];
        for (NSUInteger i = 0; i < numberOfBands; i++)
            [bands addObject:[[AVAudioUnitEQFilterParameters alloc] initForCharonEQ:self bandIndex:i]];
        _charon_bands = bands;
        _charon_globalGain = 0;
    }
    return self;
}

- (NSArray<AVAudioUnitEQFilterParameters *> *)bands
{
    return _charon_bands;
}

- (float)globalGain
{
    return _charon_globalGain;
}

- (void)setGlobalGain:(float)globalGain
{
    _charon_globalGain = globalGain;
    [self charon_setParameterID:kAUNBandEQParam_GlobalGain bandIndex:0 value:globalGain];
}

- (void)charon_setParameterID:(AudioUnitParameterID)paramID bandIndex:(NSUInteger)bandIndex value:(AudioUnitParameterValue)value
{
    AudioUnit unit = [self charon_impl]->audioUnit;
    if (!unit)
        return;   // no real unit yet - charon_applyPendingParameters replays every kept value once attached
    AudioUnitParameterID resolved = paramID == kAUNBandEQParam_GlobalGain ? paramID : (AudioUnitParameterID)(paramID + bandIndex);
    AudioUnitSetParameter(unit, resolved, kAudioUnitScope_Global, 0, value, 0);
}

- (void)charon_applyPendingParameters
{
    [super charon_applyPendingParameters];
    AudioUnit unit = [self charon_impl]->audioUnit;
    if (!unit)
        return;
    UInt32 numberOfBands = (UInt32)_charon_bands.count;
    AudioUnitSetProperty(unit, kCharonNBandEQNumberOfBands, kAudioUnitScope_Global, 0, &numberOfBands, sizeof(numberOfBands));
    [self charon_setParameterID:kAUNBandEQParam_GlobalGain bandIndex:0 value:_charon_globalGain];
    NSUInteger index = 0;
    for (AVAudioUnitEQFilterParameters *band in _charon_bands) {
        [self charon_setParameterID:kAUNBandEQParam_FilterType bandIndex:index value:(AudioUnitParameterValue)band.filterType];
        [self charon_setParameterID:kAUNBandEQParam_Frequency bandIndex:index value:band.frequency];
        [self charon_setParameterID:kAUNBandEQParam_Bandwidth bandIndex:index value:band.bandwidth];
        [self charon_setParameterID:kAUNBandEQParam_Gain bandIndex:index value:band.gain];
        [self charon_setParameterID:kAUNBandEQParam_BypassBand bandIndex:index value:band.bypass ? 1 : 0];
        index++;
    }
}

@end
