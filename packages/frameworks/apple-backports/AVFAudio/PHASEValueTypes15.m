#import "RevenantAVFAudio.h"
#import <PHASE/PHASE.h>

@implementation PHASENumericPair {
    double _revenant_first;
    double _revenant_second;
}

- (instancetype)initWithFirstValue:(double)first secondValue:(double)second
{
    if ((self = [super init])) {
        _revenant_first = first;
        _revenant_second = second;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithFirstValue:0.0 secondValue:0.0];
}

- (double)first
{
    return _revenant_first;
}

- (void)setFirst:(double)first
{
    _revenant_first = first;
}

- (double)second
{
    return _revenant_second;
}

- (void)setSecond:(double)second
{
    _revenant_second = second;
}

@end

@implementation PHASEDistanceModelFadeOutParameters {
    double _revenant_cullDistance;
}

- (instancetype)initWithCullDistance:(double)cullDistance
{
    if ((self = [super init])) {
        _revenant_cullDistance = cullDistance;
    }
    return self;
}

- (double)cullDistance
{
    return _revenant_cullDistance;
}

@end

@implementation PHASEGeometricSpreadingDistanceModelParameters {
    double _revenant_rolloffFactor;
    BOOL _revenant_rolloffSet;
}

- (double)rolloffFactor
{
    return _revenant_rolloffSet ? _revenant_rolloffFactor : 1.0;
}

- (void)setRolloffFactor:(double)rolloffFactor
{
    _revenant_rolloffFactor = rolloffFactor;
    _revenant_rolloffSet = YES;
}

- (double)revenant_gainAtDistance:(double)distance
{
    if (distance <= 0) {
        return 0;
    }
    return 1.0 / pow(distance, _revenant_rolloffFactor);
}

@end

@implementation PHASEDistanceModelParameters {
    PHASEDistanceModelFadeOutParameters *_revenant_fadeOut;
}

- (PHASEDistanceModelFadeOutParameters *)fadeOutParameters
{
    return _revenant_fadeOut;
}

- (void)setFadeOutParameters:(PHASEDistanceModelFadeOutParameters *)fadeOutParameters
{
    _revenant_fadeOut = fadeOutParameters;
}

@end

@implementation PHASEDirectivityModelParameters
@end

@implementation PHASECardioidDirectivityModelSubbandParameters {
    double _revenant_frequency;
    double _revenant_pattern;
    double _revenant_sharpness;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _revenant_frequency = 1000.0;
        _revenant_pattern = 0.0;
        _revenant_sharpness = 1.0;
    }
    return self;
}

- (double)frequency
{
    return _revenant_frequency;
}

- (void)setFrequency:(double)frequency
{
    _revenant_frequency = frequency;
}

- (double)pattern
{
    return _revenant_pattern;
}

- (void)setPattern:(double)pattern
{
    _revenant_pattern = pattern;
}

- (double)sharpness
{
    return _revenant_sharpness;
}

- (void)setSharpness:(double)sharpness
{
    _revenant_sharpness = sharpness;
}

@end

@implementation PHASEConeDirectivityModelSubbandParameters {
    double _revenant_frequency;
    double _revenant_innerAngle;
    double _revenant_outerAngle;
    double _revenant_outerGain;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _revenant_frequency = 1000.0;
        _revenant_innerAngle = 360.0;
        _revenant_outerAngle = 360.0;
        _revenant_outerGain = 1.0;
    }
    return self;
}

- (void)setInnerAngle:(double)innerAngle outerAngle:(double)outerAngle
{
    if (outerAngle < innerAngle) {
        return;
    }
    _revenant_innerAngle = innerAngle;
    _revenant_outerAngle = outerAngle;
}

- (double)frequency
{
    return _revenant_frequency;
}

- (void)setFrequency:(double)frequency
{
    _revenant_frequency = frequency;
}

- (double)innerAngle
{
    return _revenant_innerAngle;
}

- (double)outerAngle
{
    return _revenant_outerAngle;
}

- (double)outerGain
{
    return _revenant_outerGain;
}

- (void)setOuterGain:(double)outerGain
{
    _revenant_outerGain = outerGain;
}

@end

@implementation PHASECardioidDirectivityModelParameters {
    NSArray<PHASECardioidDirectivityModelSubbandParameters *> *_revenant_subbands;
}

- (instancetype)initWithSubbandParameters:(NSArray<PHASECardioidDirectivityModelSubbandParameters *> *)subbandParameters
{
    if ((self = [PHASECardioidDirectivityModelParameters alloc])) {
        _revenant_subbands = [subbandParameters copy] ?: @[];
    }
    return self;
}

- (NSArray<PHASECardioidDirectivityModelSubbandParameters *> *)subbandParameters
{
    return _revenant_subbands;
}

@end

@implementation PHASEConeDirectivityModelParameters {
    NSArray<PHASEConeDirectivityModelSubbandParameters *> *_revenant_subbands;
}

- (instancetype)initWithSubbandParameters:(NSArray<PHASEConeDirectivityModelSubbandParameters *> *)subbandParameters
{
    if ((self = [PHASEConeDirectivityModelParameters alloc])) {
        _revenant_subbands = [subbandParameters copy] ?: @[];
    }
    return self;
}

- (NSArray<PHASEConeDirectivityModelSubbandParameters *> *)subbandParameters
{
    return _revenant_subbands;
}

@end
