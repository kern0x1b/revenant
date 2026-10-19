#import "CharonAVAudioEngine.h"

// AVAudioUnit/AVAudioUnitEffect/AVAudioUnitEQ over a real AudioUnit inside AVAudioEngine's own
// AUGraph - same objc.inventory/grep discipline as CharonAVAudioEngine.h: none of these four class
// names collide with anything native to 6.0/6.1.3, checked before this was written (see
// facts/AVFoundation/AVAudioEngine.md). kAudioUnitSubType_NBandEQ is confirmed registered via
// AudioComponentFindNext on the real device, same source.
//
// Every writable property here (filterType/frequency/bandwidth/gain/bypass/globalGain) can be set
// before the node is attached to an engine, exactly as a real caller is free to configure an
// AVAudioUnitEQ before -attachNode: - there is no real AudioUnit yet at that point, so the value is
// only kept, not applied. -charon_applyPendingParameters is the hook AVAudioEngine's -attachNode:
// calls right after the real AUNode/AudioUnit come into existence, pushing every kept value onto
// the audio unit in one pass.

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioUnit : AVAudioNode
// Private designated init shared by every AVAudioUnit subclass this port ships - genuinely an
// -init-family method (ARC requires the selector to literally start with "init" to allow the
// self = [super init] assignment), just not the public initializer the real class exposes.
- (instancetype)initWithCharonComponentDescription:(AudioComponentDescription)description name:(NSString *)name manufacturerName:(NSString *)manufacturerName version:(NSUInteger)version;
@property (nonatomic, readonly) AudioComponentDescription audioComponentDescription;
@property (nonatomic, readonly) AudioUnit audioUnit;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSUInteger version;
- (BOOL)loadAudioUnitPresetAtURL:(NSURL *)url error:(NSError **)outError;
// Called by AVAudioEngine's -attachNode: once the real AudioUnit exists, so a value set on a
// property before the node was ever attached still reaches the real unit - never call directly.
// Base class does nothing; AVAudioUnitEffect and its subclasses override.
- (void)charon_applyPendingParameters;
@end

@interface AVAudioUnitEffect : AVAudioUnit
- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)description;
@property (nonatomic) BOOL bypass;
@end

typedef NS_ENUM(NSInteger, AVAudioUnitEQFilterType) {
    AVAudioUnitEQFilterTypeParametric        = 0,
    AVAudioUnitEQFilterTypeLowPass           = 1,
    AVAudioUnitEQFilterTypeHighPass          = 2,
    AVAudioUnitEQFilterTypeResonantLowPass   = 3,
    AVAudioUnitEQFilterTypeResonantHighPass  = 4,
    AVAudioUnitEQFilterTypeBandPass          = 5,
    AVAudioUnitEQFilterTypeBandStop          = 6,
    AVAudioUnitEQFilterTypeLowShelf          = 7,
    AVAudioUnitEQFilterTypeHighShelf         = 8,
    AVAudioUnitEQFilterTypeResonantLowShelf  = 9,
    AVAudioUnitEQFilterTypeResonantHighShelf = 10,
};

@class AVAudioUnitEQ;

@interface AVAudioUnitEQFilterParameters : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initForCharonEQ:(AVAudioUnitEQ *)eq bandIndex:(NSUInteger)bandIndex;
@property (nonatomic) AVAudioUnitEQFilterType filterType;
@property (nonatomic) float frequency;
@property (nonatomic) float bandwidth;
@property (nonatomic) float gain;
@property (nonatomic) BOOL bypass;
@end

@interface AVAudioUnitEQ : AVAudioUnitEffect
- (instancetype)initWithNumberOfBands:(NSUInteger)numberOfBands;
@property (nonatomic, readonly) NSArray<AVAudioUnitEQFilterParameters *> *bands;
@property (nonatomic) float globalGain;
// Real parameter/property IDs are AUNBandEQ's own (AudioUnitParameters.h) - band's own writable
// properties funnel here rather than touching the AudioUnit directly, so a value set before attach
// and one set after go through the same path.
- (void)charon_setParameterID:(AudioUnitParameterID)paramID bandIndex:(NSUInteger)bandIndex value:(AudioUnitParameterValue)value;
@end

NS_ASSUME_NONNULL_END
