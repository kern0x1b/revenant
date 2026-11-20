#import "RevenantAVAudioEngine.h"
#import "RevenantAVAudioBuffer.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    AudioUnit unit;
    double rate;
    int16_t *scratch;
    UInt32 scratchFrames;
    void *pump;
    volatile int32_t muted;
} RevenantInputState;

@interface RevenantTapPump : NSObject
- (instancetype)initWithFormat:(AVAudioFormat *)format bufferSize:(AVAudioFrameCount)bufferSize block:(AVAudioNodeTapBlock)block;
@property (nonatomic, readonly) AVAudioFormat *format;
@property (nonatomic) double sourceRate;
- (void)writeInt16:(const int16_t *)samples frames:(UInt32)frames stride:(UInt32)stride muted:(BOOL)muted;
- (void)writeFloat:(const float *)samples frames:(UInt32)frames stride:(UInt32)stride;
- (void)stop;
@end

OSStatus RevenantInputRenderCallback(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timeStamp,
                                     UInt32 bus, UInt32 frames, AudioBufferList *data);
OSStatus RevenantTapRenderNotify(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timeStamp,
                                 UInt32 bus, UInt32 frames, AudioBufferList *data);

@interface AVAudioNode (RevenantTap)
- (nullable RevenantTapPump *)revenant_pump;
@end

@interface AVAudioInputNode (RevenantInput)
- (RevenantInputState *)revenant_inputState;
@end

@interface AVAudioEngine (RevenantInput)
- (BOOL)revenant_setVoiceProcessingEnabled:(BOOL)enabled error:(NSError * _Nullable * _Nullable)outError;
- (void)revenant_applyVoiceProcessing;
- (void)revenant_inputChanged;
@end

NS_ASSUME_NONNULL_END
