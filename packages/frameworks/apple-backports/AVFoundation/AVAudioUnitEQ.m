#import "RevenantAVAudioUnit.h"

static const AudioUnitPropertyID kRevenantNBandEQNumberOfBands = 2200;

@implementation AVAudioUnitEQFilterParameters {
    __weak AVAudioUnitEQ *_revenant_eq;
    NSUInteger _revenant_bandIndex;
    AVAudioUnitEQFilterType _filterType;
    float _frequency;
    float _bandwidth;
    float _gain;
    BOOL _bypass;
}

- (instancetype)initForRevenantEQ:(AVAudioUnitEQ *)eq bandIndex:(NSUInteger)bandIndex
{
    if ((self = [super init])) {
        _revenant_eq = eq;
        _revenant_bandIndex = bandIndex;
        _filterType = AVAudioUnitEQFilterTypeParametric;
        _frequency = 1000;
        _bandwidth = 0.5;
        _gain = 0;
        _bypass = YES;
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
    [_revenant_eq revenant_setParameterID:kAUNBandEQParam_FilterType bandIndex:_revenant_bandIndex value:(AudioUnitParameterValue)filterType];
}

- (float)frequency
{
    return _frequency;
}

- (void)setFrequency:(float)frequency
{
    _frequency = frequency;
    [_revenant_eq revenant_setParameterID:kAUNBandEQParam_Frequency bandIndex:_revenant_bandIndex value:frequency];
}

- (float)bandwidth
{
    return _bandwidth;
}

- (void)setBandwidth:(float)bandwidth
{
    _bandwidth = bandwidth;
    [_revenant_eq revenant_setParameterID:kAUNBandEQParam_Bandwidth bandIndex:_revenant_bandIndex value:bandwidth];
}

- (float)gain
{
    return _gain;
}

- (void)setGain:(float)gain
{
    _gain = gain;
    [_revenant_eq revenant_setParameterID:kAUNBandEQParam_Gain bandIndex:_revenant_bandIndex value:gain];
}

- (BOOL)bypass
{
    return _bypass;
}

- (void)setBypass:(BOOL)bypass
{
    _bypass = bypass;
    [_revenant_eq revenant_setParameterID:kAUNBandEQParam_BypassBand bandIndex:_revenant_bandIndex value:bypass ? 1 : 0];
}

@end

@implementation AVAudioUnitEQ {
    NSArray<AVAudioUnitEQFilterParameters *> *_revenant_bands;
    float _revenant_globalGain;
}

- (instancetype)initWithNumberOfBands:(NSUInteger)numberOfBands
{
    AudioComponentDescription desc = {
        .componentType = kAudioUnitType_Effect,
        .componentSubType = kAudioUnitSubType_NBandEQ,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
    };
    if ((self = [self initWithRevenantComponentDescription:desc name:@"AUNBandEQ" manufacturerName:@"Apple" version:0])) {
        NSMutableArray<AVAudioUnitEQFilterParameters *> *bands = [NSMutableArray arrayWithCapacity:numberOfBands];
        for (NSUInteger i = 0; i < numberOfBands; i++)
            [bands addObject:[[AVAudioUnitEQFilterParameters alloc] initForRevenantEQ:self bandIndex:i]];
        _revenant_bands = bands;
        _revenant_globalGain = 0;
    }
    return self;
}

- (NSArray<AVAudioUnitEQFilterParameters *> *)bands
{
    return _revenant_bands;
}

- (float)globalGain
{
    return _revenant_globalGain;
}

- (void)setGlobalGain:(float)globalGain
{
    _revenant_globalGain = globalGain;
    [self revenant_setParameterID:kAUNBandEQParam_GlobalGain bandIndex:0 value:globalGain];
}

- (void)revenant_setParameterID:(AudioUnitParameterID)paramID bandIndex:(NSUInteger)bandIndex value:(AudioUnitParameterValue)value
{
    AudioUnit unit = [self revenant_impl]->audioUnit;
    if (!unit)
        return;
    AudioUnitParameterID resolved = paramID == kAUNBandEQParam_GlobalGain ? paramID : (AudioUnitParameterID)(paramID + bandIndex);
    AudioUnitSetParameter(unit, resolved, kAudioUnitScope_Global, 0, value, 0);
}

- (void)revenant_applyPendingParameters
{
    [super revenant_applyPendingParameters];
    AudioUnit unit = [self revenant_impl]->audioUnit;
    if (!unit)
        return;
    UInt32 numberOfBands = (UInt32)_revenant_bands.count;
    AudioUnitSetProperty(unit, kRevenantNBandEQNumberOfBands, kAudioUnitScope_Global, 0, &numberOfBands, sizeof(numberOfBands));
    [self revenant_setParameterID:kAUNBandEQParam_GlobalGain bandIndex:0 value:_revenant_globalGain];
    NSUInteger index = 0;
    for (AVAudioUnitEQFilterParameters *band in _revenant_bands) {
        [self revenant_setParameterID:kAUNBandEQParam_FilterType bandIndex:index value:(AudioUnitParameterValue)band.filterType];
        [self revenant_setParameterID:kAUNBandEQParam_Frequency bandIndex:index value:band.frequency];
        [self revenant_setParameterID:kAUNBandEQParam_Bandwidth bandIndex:index value:band.bandwidth];
        [self revenant_setParameterID:kAUNBandEQParam_Gain bandIndex:index value:band.gain];
        [self revenant_setParameterID:kAUNBandEQParam_BypassBand bandIndex:index value:band.bypass ? 1 : 0];
        index++;
    }
}

@end
