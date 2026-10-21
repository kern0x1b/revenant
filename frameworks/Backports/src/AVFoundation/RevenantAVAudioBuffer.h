#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioTypes.h>

typedef struct {
    AudioBufferList *bufferList;
    UInt32 frameCapacity;
    UInt32 frameLength;
    NSUInteger stride;
    NSUInteger channelPointerCount;
    void **channelPointers;
    UInt32 bytesPerFramePerBuffer;
} RevenantAudioBufferImpl;

NS_ASSUME_NONNULL_BEGIN

@interface RevenantAudioBuffer : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, readonly, nullable) AVAudioFormat *format;
@property (nonatomic, readonly) const AudioBufferList *audioBufferList;
@property (nonatomic, readonly) AudioBufferList *mutableAudioBufferList;
@end

@interface RevenantAudioBuffer (RevenantImpl)
- (RevenantAudioBufferImpl *)revenant_impl;
- (RevenantAudioBufferImpl *)revenant_allocate;
- (void)revenant_setFormat:(AVAudioFormat *)format;
@end

@interface AVAudioPCMBuffer : RevenantAudioBuffer
- (nullable instancetype)initWithPCMFormat:(AVAudioFormat *)format frameCapacity:(AVAudioFrameCount)frameCapacity NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly) AVAudioFrameCount frameCapacity;
@property (nonatomic) AVAudioFrameCount frameLength;
@property (nonatomic, readonly) NSUInteger stride;
@property (nonatomic, readonly) float * __nonnull const * __nullable floatChannelData;
@property (nonatomic, readonly) int16_t * __nonnull const * __nullable int16ChannelData;
@property (nonatomic, readonly) int32_t * __nonnull const * __nullable int32ChannelData;
@end

NS_ASSUME_NONNULL_END
