#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioTypes.h>

// `AVAudioBuffer` is a real, measured trap, not a guess: the class name is already native to
// iOS 6.0/6.1.3's own AVFoundation.framework (`objc.inventory` against the real armv7 shared
// cache confirms it), but as a completely different, private, AudioQueue-era class
// (`-initWithAudioQueueBuffer:channels:`, `-packetDescriptions`, `-bytesDataSize`, no `format`,
// no `audioBufferList`) that predates and has nothing to do with the class of the same name
// AVFAudio introduced in iOS 8. The build gate's own `band()`/`duplicated()` check catches
// exactly this - "the band cannot leave a class out that nothing says is there... carry it under
// a name of Charon's own" - so this port's base class lives under `CharonAudioBuffer`, never
// under the real, already-taken `AVAudioBuffer` name.
//
// `AVAudioPCMBuffer` itself is not native to any release this port targets (confirmed absent on
// both 6.0 and 6.1.3), so it keeps its real name; only its *runtime* superclass differs from what
// Apple's own header declares. That difference is invisible to every caller: Objective-C dispatch
// is dynamic, and an application compiled against Apple's SDK header (which does say
// `AVAudioPCMBuffer : AVAudioBuffer`) only ever sends selectors - it never inspects which class
// actually implements them at link time - so every method a real caller sends still resolves
// here, correctly, regardless of the header's own claimed ancestry.

// Only plain C data lives in this struct, on purpose: ARC does not retain an Objective-C pointer
// stored in a malloc'd struct field just because the field's declared type is an object pointer -
// only real ivars and locals get that. `format` used to live here and was a latent dangling-
// pointer bug (nothing kept it alive once a caller dropped its own reference to the format object
// used to build the buffer) until a real ivar on CharonAudioBuffer replaced it - see AVAudioBuffer8.m.
typedef struct {
    AudioBufferList *bufferList;
    UInt32 frameCapacity;
    UInt32 frameLength;
    NSUInteger stride;
    NSUInteger channelPointerCount;
    void **channelPointers;      // cached float*/int16_t*/int32_t* per channel, or NULL if commonFormat doesn't match
    UInt32 bytesPerFramePerBuffer;
} CharonAudioBufferImpl;

NS_ASSUME_NONNULL_BEGIN

@interface CharonAudioBuffer : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, readonly, nullable) AVAudioFormat *format;
@property (nonatomic, readonly) const AudioBufferList *audioBufferList;
@property (nonatomic, readonly) AudioBufferList *mutableAudioBufferList;
@end

@interface CharonAudioBuffer (CharonImpl)
- (CharonAudioBufferImpl *)charon_impl;
- (CharonAudioBufferImpl *)charon_allocate;
- (void)charon_setFormat:(AVAudioFormat *)format;
@end

@interface AVAudioPCMBuffer : CharonAudioBuffer
- (nullable instancetype)initWithPCMFormat:(AVAudioFormat *)format frameCapacity:(AVAudioFrameCount)frameCapacity NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) AVAudioFrameCount frameCapacity;
@property (nonatomic) AVAudioFrameCount frameLength;
@property (nonatomic, readonly) NSUInteger stride;
@property (nonatomic, readonly) float * __nonnull const * __nullable floatChannelData;
@property (nonatomic, readonly) int16_t * __nonnull const * __nullable int16ChannelData;
@property (nonatomic, readonly) int32_t * __nonnull const * __nullable int32ChannelData;
@end

NS_ASSUME_NONNULL_END
