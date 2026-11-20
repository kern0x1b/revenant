#import "RevenantAVAudioEngine.h"
#import "RevenantAVAudioBuffer.h"

NS_ASSUME_NONNULL_BEGIN

// The state of the microphone side of an engine, read by the audio unit's input callback on the audio thread.
// It is allocated by the input node and lives as long as the node does; the engine fills it in `prepare`.
typedef struct {
    AudioUnit unit;
    double rate;
    int16_t *scratch;
    UInt32 scratchFrames;
    void *pump;
    volatile int32_t muted;
} RevenantInputState;

// Delivers audio from the render thread to a tap block, the way AVAudioNode's installTap does: in blocks of
// `bufferSize` frames of the tap's format, on a serial queue of its own, never on the render thread.
// The render thread only converts the samples to the tap's rate and writes them into a ring buffer; the queue
// reads them back, builds an AVAudioPCMBuffer and calls the block. A full ring drops the newest samples.
@interface RevenantTapPump : NSObject
- (instancetype)initWithFormat:(AVAudioFormat *)format bufferSize:(AVAudioFrameCount)bufferSize block:(AVAudioNodeTapBlock)block;
@property (nonatomic, readonly) AVAudioFormat *format;
// The sample rate of the audio the render thread writes. It differs from the tap's when the source runs at its own rate.
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
