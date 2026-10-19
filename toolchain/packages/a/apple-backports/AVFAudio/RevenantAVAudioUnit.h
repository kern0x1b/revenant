#import "CharonAUAudioUnit.h"

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioUnit (CharonAVFAudioImpl)
- (instancetype)initWithCharonComponentDescription:(AudioComponentDescription)description
                                              name:(NSString *_Nullable)name
                                  manufacturerName:(NSString *_Nullable)manufacturerName
                                           version:(NSUInteger)version;
- (void)charon_applyPendingParameters;
@end

@interface AVAudioUnitGenerator (CharonAVFAudioImpl)
- (instancetype)initWithCharonComponentDescription:(AudioComponentDescription)description
                                              name:(NSString *_Nullable)name
                                  manufacturerName:(NSString *_Nullable)manufacturerName
                                           version:(NSUInteger)version;
@end

static inline AudioComponentDescription CharonUnitDescription(OSType unitType, OSType subType)
{
    AudioComponentDescription description = {0};
    description.componentType = unitType;
    description.componentSubType = subType;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    return description;
}

static inline float CharonUnitParameter(AudioUnit unit, AudioUnitParameterID identifier)
{
    if (unit == NULL) {
        return 0;
    }
    AudioUnitParameterValue value = 0;
    if (AudioUnitGetParameter(unit, identifier, kAudioUnitScope_Global, 0, &value) != noErr) {
        return 0;
    }
    return (float)value;
}

static inline void CharonSetUnitParameter(AudioUnit unit, AudioUnitParameterID identifier, float value)
{
    if (unit == NULL) {
        return;
    }
    AudioUnitSetParameter(unit, identifier, kAudioUnitScope_Global, 0, (AudioUnitParameterValue)value, 0);
}

NS_ASSUME_NONNULL_END
