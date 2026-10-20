#import "RevenantAVAudioEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioUnit : AVAudioNode
- (instancetype)initWithRevenantComponentDescription:(AudioComponentDescription)description name:(NSString *)name manufacturerName:(NSString *)manufacturerName version:(NSUInteger)version;
@property (nonatomic, readonly) AudioComponentDescription audioComponentDescription;
@property (nonatomic, readonly) AudioUnit audioUnit;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSUInteger version;
- (BOOL)loadAudioUnitPresetAtURL:(NSURL *)url error:(NSError **)outError;
- (void)revenant_applyPendingParameters;
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
- (instancetype)initForRevenantEQ:(AVAudioUnitEQ *)eq bandIndex:(NSUInteger)bandIndex;
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
- (void)revenant_setParameterID:(AudioUnitParameterID)paramID bandIndex:(NSUInteger)bandIndex value:(AudioUnitParameterValue)value;
@end

NS_ASSUME_NONNULL_END
