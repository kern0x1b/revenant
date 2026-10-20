#import "RevenantAVAudioEngine.h"
#import "RevenantAVAudioBuffer.h"

OSStatus RevenantPlayerRenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    AVAudioPlayerNode *node = (__bridge AVAudioPlayerNode *)inRefCon;
    NSMutableArray<RevenantScheduledBuffer *> *queue = [node revenant_queue];
    RevenantAudioNodeImpl *impl = [node revenant_impl];

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
            RevenantScheduledBuffer *scheduled = queue.firstObject;
            AVAudioPCMBuffer *source = scheduled.buffer;
            RevenantAudioBufferImpl *sourceImpl = [source revenant_impl];
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
    RevenantScheduledBuffer *scheduled = [RevenantScheduledBuffer new];
    scheduled.buffer = buffer;
    scheduled.completionHandler = completionHandler;
    scheduled.framesConsumed = 0;
    NSMutableArray *queue = [self revenant_queue];
    @synchronized(queue) {
        [queue addObject:scheduled];
    }
    if (![self revenant_impl]->attached)
        [self revenant_setFormat:buffer.format];
}

- (void)play
{
    [self revenant_impl]->playing = YES;
}

- (void)pause
{
    [self revenant_impl]->playing = NO;
}

- (void)stop
{
    RevenantAudioNodeImpl *impl = [self revenant_impl];
    impl->playing = NO;
    NSMutableArray *queue = [self revenant_queue];
    @synchronized(queue) {
        [queue removeAllObjects];
    }
}

- (BOOL)isPlaying
{
    return [self revenant_impl]->playing;
}

@end
