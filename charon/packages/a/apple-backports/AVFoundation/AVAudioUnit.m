#import "CharonAVAudioUnit.h"

@implementation AVAudioUnit {
    AudioComponentDescription _charon_desc;
    NSString *_charon_name;
    NSString *_charon_manufacturerName;
    NSUInteger _charon_version;
}

- (instancetype)initWithCharonComponentDescription:(AudioComponentDescription)description name:(NSString *)name manufacturerName:(NSString *)manufacturerName version:(NSUInteger)version
{
    if ((self = [super init])) {
        _charon_desc = description;
        _charon_name = [name copy];
        _charon_manufacturerName = [manufacturerName copy];
        _charon_version = version;
    }
    return self;
}

- (AudioComponentDescription)audioComponentDescription
{
    return _charon_desc;
}

- (AudioUnit)audioUnit
{
    return [self charon_impl]->audioUnit;
}

- (NSString *)name
{
    return _charon_name;
}

- (NSString *)manufacturerName
{
    return _charon_manufacturerName;
}

- (NSUInteger)version
{
    return _charon_version;
}

// A real .aupreset is a plist read through the component's own kAudioUnitProperty_ClassInfo -
// nothing this port's own NBandEQ/effect wiring depends on, and no application in the corpus needs
// it yet (see COORDINATION.md section 3, demand-driven). Honestly refuses rather than faking a
// preset load that silently does nothing.
- (BOOL)loadAudioUnitPresetAtURL:(NSURL *)url error:(NSError **)outError
{
    if (outError)
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudio_UnimplementedError userInfo:nil];
    return NO;
}

- (void)charon_applyPendingParameters
{
}

@end

@implementation AVAudioUnitEffect {
    BOOL _charon_bypass;
}

- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)description
{
    return [self initWithCharonComponentDescription:description name:@"AUEffect" manufacturerName:@"Apple" version:0];
}

- (BOOL)bypass
{
    return _charon_bypass;
}

// kAudioUnitProperty_BypassEffect is generic to every real Apple effect unit, not NBandEQ-specific
// - applying it here, once, at the AVAudioUnitEffect level covers every subclass this port ever
// adds, the same way Apple's own class hierarchy puts bypass on the base rather than each concrete
// effect.
- (void)setBypass:(BOOL)bypass
{
    _charon_bypass = bypass;
    AudioUnit unit = [self charon_impl]->audioUnit;
    if (unit) {
        UInt32 flag = bypass ? 1 : 0;
        AudioUnitSetProperty(unit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &flag, sizeof(flag));
    }
}

- (void)charon_applyPendingParameters
{
    self.bypass = _charon_bypass;
}

@end
