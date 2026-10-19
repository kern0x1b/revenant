#import "RevenantAVAudioUnit.h"

@implementation AVAudioUnit {
    AudioComponentDescription _revenant_desc;
    NSString *_revenant_name;
    NSString *_revenant_manufacturerName;
    NSUInteger _revenant_version;
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
    if (outError)
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudio_UnimplementedError userInfo:nil];
    return NO;
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
