#import "CharonAVFAudio.h"
#import <PHASE/PHASE.h>

@implementation PHASENumericPair {
    double _charon_first;
    double _charon_second;
}

- (instancetype)initWithFirstValue:(double)first secondValue:(double)second
{
    if ((self = [super init])) {
        _charon_first = first;
        _charon_second = second;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithFirstValue:0.0 secondValue:0.0];
}

- (double)first
{
    return _charon_first;
}

- (void)setFirst:(double)first
{
    _charon_first = first;
}

- (double)second
{
    return _charon_second;
}

- (void)setSecond:(double)second
{
    _charon_second = second;
}

@end

@implementation PHASEDistanceModelFadeOutParameters {
    double _charon_cullDistance;
}

- (instancetype)initWithCullDistance:(double)cullDistance
{
    if ((self = [super init])) {
        _charon_cullDistance = cullDistance;
    }
    return self;
}

- (double)cullDistance
{
    return _charon_cullDistance;
}

@end

@implementation PHASEGeometricSpreadingDistanceModelParameters {
    double _charon_rolloffFactor;
    BOOL _charon_rolloffSet;
}

- (double)rolloffFactor
{
    return _charon_rolloffSet ? _charon_rolloffFactor : 1.0;
}

- (void)setRolloffFactor:(double)rolloffFactor
{
    _charon_rolloffFactor = rolloffFactor;
    _charon_rolloffSet = YES;
}

- (double)charon_gainAtDistance:(double)distance
{
    if (distance <= 0) {
        return 0;
    }
    return 1.0 / pow(distance, _charon_rolloffFactor);
}

@end

@implementation PHASEDistanceModelParameters {
    PHASEDistanceModelFadeOutParameters *_charon_fadeOut;
}

- (PHASEDistanceModelFadeOutParameters *)fadeOutParameters
{
    return _charon_fadeOut;
}

- (void)setFadeOutParameters:(PHASEDistanceModelFadeOutParameters *)fadeOutParameters
{
    _charon_fadeOut = fadeOutParameters;
}

@end

@implementation PHASEDirectivityModelParameters
@end

@implementation PHASECardioidDirectivityModelSubbandParameters {
    double _charon_frequency;
    double _charon_pattern;
    double _charon_sharpness;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _charon_frequency = 1000.0;
        _charon_pattern = 0.0;
        _charon_sharpness = 1.0;
    }
    return self;
}

- (double)frequency
{
    return _charon_frequency;
}

- (void)setFrequency:(double)frequency
{
    _charon_frequency = frequency;
}

- (double)pattern
{
    return _charon_pattern;
}

- (void)setPattern:(double)pattern
{
    _charon_pattern = pattern;
}

- (double)sharpness
{
    return _charon_sharpness;
}

- (void)setSharpness:(double)sharpness
{
    _charon_sharpness = sharpness;
}

@end

@implementation PHASEConeDirectivityModelSubbandParameters {
    double _charon_frequency;
    double _charon_innerAngle;
    double _charon_outerAngle;
    double _charon_outerGain;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _charon_frequency = 1000.0;
        _charon_innerAngle = 360.0;
        _charon_outerAngle = 360.0;
        _charon_outerGain = 1.0;
    }
    return self;
}

- (void)setInnerAngle:(double)innerAngle outerAngle:(double)outerAngle
{
    if (outerAngle < innerAngle) {
        return;
    }
    _charon_innerAngle = innerAngle;
    _charon_outerAngle = outerAngle;
}

- (double)frequency
{
    return _charon_frequency;
}

- (void)setFrequency:(double)frequency
{
    _charon_frequency = frequency;
}

- (double)innerAngle
{
    return _charon_innerAngle;
}

- (double)outerAngle
{
    return _charon_outerAngle;
}

- (double)outerGain
{
    return _charon_outerGain;
}

- (void)setOuterGain:(double)outerGain
{
    _charon_outerGain = outerGain;
}

@end

@implementation PHASECardioidDirectivityModelParameters {
    NSArray<PHASECardioidDirectivityModelSubbandParameters *> *_charon_subbands;
}

- (instancetype)initWithSubbandParameters:(NSArray<PHASECardioidDirectivityModelSubbandParameters *> *)subbandParameters
{
    if ((self = [PHASECardioidDirectivityModelParameters alloc])) {
        _charon_subbands = [subbandParameters copy] ?: @[];
    }
    return self;
}

- (NSArray<PHASECardioidDirectivityModelSubbandParameters *> *)subbandParameters
{
    return _charon_subbands;
}

@end

@implementation PHASEConeDirectivityModelParameters {
    NSArray<PHASEConeDirectivityModelSubbandParameters *> *_charon_subbands;
}

- (instancetype)initWithSubbandParameters:(NSArray<PHASEConeDirectivityModelSubbandParameters *> *)subbandParameters
{
    if ((self = [PHASEConeDirectivityModelParameters alloc])) {
        _charon_subbands = [subbandParameters copy] ?: @[];
    }
    return self;
}

- (NSArray<PHASEConeDirectivityModelSubbandParameters *> *)subbandParameters
{
    return _charon_subbands;
}

@end
