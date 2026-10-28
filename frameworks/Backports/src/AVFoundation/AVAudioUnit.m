#import "RevenantAVAudioUnit.h"
#import "RevenantAudioUnitPreset.h"

@implementation AVAudioUnit {
    AudioComponentDescription _revenant_desc;
    NSString *_revenant_name;
    NSString *_revenant_manufacturerName;
    NSUInteger _revenant_version;
    NSDictionary *_revenant_pendingPreset;
}

- (instancetype)initWithRevenantComponentDescription:(AudioComponentDescription)description name:(NSString *)name manufacturerName:(NSString *)manufacturerName version:(NSUInteger)version
{
    if ((self = [super init])) {
        _revenant_desc = description;
        _revenant_name = [name copy];
        _revenant_manufacturerName = [manufacturerName copy];
        _revenant_version = version;
    }
    return self;
}

- (AudioComponentDescription)audioComponentDescription
{
    return _revenant_desc;
}

- (AudioUnit)audioUnit
{
    return [self revenant_impl]->audioUnit;
}

- (NSString *)name
{
    return _revenant_name;
}

- (NSString *)manufacturerName
{
    return _revenant_manufacturerName;
}

- (NSUInteger)version
{
    return _revenant_version;
}

- (BOOL)loadAudioUnitPresetAtURL:(NSURL *)url error:(NSError **)outError
{
    NSDictionary *preset = RevenantAudioUnitReadPreset(url, outError);
    if (!preset)
        return NO;
    AudioUnit unit = self.audioUnit;
    if (!unit) {
        _revenant_pendingPreset = preset;
        return YES;
    }
    return RevenantAudioUnitApplyPreset(unit, preset, outError);
}

- (void)revenant_setEngine:(AVAudioEngine *)engine auNode:(AUNode)node audioUnit:(AudioUnit)unit
{
    [super revenant_setEngine:engine auNode:node audioUnit:unit];
    if (unit && _revenant_pendingPreset) {
        NSError *error = nil;
        if (!RevenantAudioUnitApplyPreset(unit, _revenant_pendingPreset, &error))
            NSLog(@"AVAudioUnit loadAudioUnitPresetAtURL:error: the preset could not be applied when the engine attached the unit; it stays at its defaults: %@", error);
        _revenant_pendingPreset = nil;
    }
}

- (void)revenant_applyPendingParameters
{
}

@end

@implementation AVAudioUnitEffect {
    BOOL _revenant_bypass;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)description
{
    return [self initWithRevenantComponentDescription:description name:@"AUEffect" manufacturerName:@"Apple" version:0];
}

- (BOOL)bypass
{
    return _revenant_bypass;
}

- (void)setBypass:(BOOL)bypass
{
    _revenant_bypass = bypass;
    AudioUnit unit = [self revenant_impl]->audioUnit;
    if (unit) {
        UInt32 flag = bypass ? 1 : 0;
        AudioUnitSetProperty(unit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &flag, sizeof(flag));
    }
}

- (void)revenant_applyPendingParameters
{
    self.bypass = _revenant_bypass;
}

@end
