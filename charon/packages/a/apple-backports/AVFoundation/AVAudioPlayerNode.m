#import "CharonAVAudioEngine.h"
#import "CharonAVAudioBuffer.h"

// AVAudioPlayerNode carries no AudioUnit of its own - see CharonAVAudioEngine.h for why. What it
// really is: a queue of scheduled buffers, read frame-by-frame by CharonPlayerRenderCallback,
// which AVAudioEngine wires directly onto whatever real node the player is connected to via
// AUGraphSetNodeInputCallback. Silence-on-empty is deliberate and matches the real class: an
// unscheduled or exhausted player renders silence, not an error, exactly like the underlying
// AudioUnit render contract already works.

// A raw byte copy is correct here, not merely convenient: -connect:to:format: only ever completes
// when the destination's format has already been forced to match the source (the same rule the
// real class documents), so the buffer being read here and the AudioBufferList being written into
// are the same PCM layout - same bytes-per-frame, same channel count, same (non-)interleaving.
OSStatus CharonPlayerRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    AVAudioPlayerNode *node = (__bridge AVAudioPlayerNode *)inRefCon;
    NSMutableArray<CharonScheduledBuffer *> *queue = [node charon_queue];
    CharonAudioNodeImpl *impl = [node charon_impl];

    for (UInt32 b = 0; b < ioData->mNumberBuffers; b++)
        memset(ioData->mBuffers[b].mData, 0, ioData->mBuffers[b].mDataByteSize);

    @synchronized(queue) {
        if (!impl->playing || queue.count == 0) {
            if (ioActionFlags)
                *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
            return noErr;
        }

        UInt32 framesFilled = 0;
        while (framesFilled < inNumberFrames && queue.count > 0) {
            CharonScheduledBuffer *scheduled = queue.firstObject;
            AVAudioPCMBuffer *source = scheduled.buffer;
            CharonAudioBufferImpl *sourceImpl = [source charon_impl];
            AVAudioFrameCount available = [source frameLength] - scheduled.framesConsumed;
            UInt32 toCopy = MIN(available, inNumberFrames - framesFilled);

            for (UInt32 b = 0; b < ioData->mNumberBuffers && b < sourceImpl->bufferList->mNumberBuffers; b++) {
                UInt32 bytesPerFrame = sourceImpl->bytesPerFramePerBuffer;
                uint8_t *src = (uint8_t *)sourceImpl->bufferList->mBuffers[b].mData + (size_t)scheduled.framesConsumed * bytesPerFrame;
                uint8_t *dst = (uint8_t *)ioData->mBuffers[b].mData + (size_t)framesFilled * bytesPerFrame;
                memcpy(dst, src, (size_t)toCopy * bytesPerFrame);
            }

            scheduled.framesConsumed += toCopy;
            framesFilled += toCopy;

            if (scheduled.framesConsumed >= [source frameLength]) {
                [queue removeObjectAtIndex:0];
                void (^completion)(void) = scheduled.completionHandler;
                if (completion)
                    dispatch_async(dispatch_get_main_queue(), completion);
            }
        }
    }
    return noErr;
}

@implementation AVAudioPlayerNode

- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer completionHandler:(void (^)(void))completionHandler
{
    [self scheduleBuffer:buffer atTime:nil options:0 completionHandler:completionHandler];
}

- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer atTime:(AVAudioTime *)when options:(NSUInteger)options completionHandler:(void (^)(void))completionHandler
{
    CharonScheduledBuffer *scheduled = [CharonScheduledBuffer new];
    scheduled.buffer = buffer;
    scheduled.completionHandler = completionHandler;
    scheduled.framesConsumed = 0;
    NSMutableArray *queue = [self charon_queue];
    @synchronized(queue) {
        [queue addObject:scheduled];
    }
    if (![self charon_impl]->attached)
        [self charon_setFormat:buffer.format];
}

- (void)play
{
    [self charon_impl]->playing = YES;
}

- (void)pause
{
    [self charon_impl]->playing = NO;
}

- (void)stop
{
    CharonAudioNodeImpl *impl = [self charon_impl];
    impl->playing = NO;
    NSMutableArray *queue = [self charon_queue];
    @synchronized(queue) {
        [queue removeAllObjects];
    }
}

- (BOOL)isPlaying
{
    return [self charon_impl]->playing;
}

@end
