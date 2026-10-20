#import <AudioToolbox/AudioQueue.h>
#import <dispatch/dispatch.h>
#import <stdlib.h>
#import <string.h>

@interface RevenantAudioQueueDispatch : NSObject
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy) id callback;
@end

@implementation RevenantAudioQueueDispatch
@synthesize queue = _queue;
@synthesize callback = _callback;
@end

static void RevenantAudioQueueOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
    RevenantAudioQueueDispatch *dispatch = (__bridge RevenantAudioQueueDispatch *)inUserData;
    AudioQueueOutputCallbackBlock block = (AudioQueueOutputCallbackBlock)dispatch.callback;
    dispatch_async(dispatch.queue, ^{
        block(inAQ, inBuffer);
    });
}

static void RevenantAudioQueueInputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer,
                                          const AudioTimeStamp *inStartTime, UInt32 inNumberPacketDescriptions,
                                          const AudioStreamPacketDescription *inPacketDescs)
{
    RevenantAudioQueueDispatch *dispatch = (__bridge RevenantAudioQueueDispatch *)inUserData;
    AudioQueueInputCallbackBlock block = (AudioQueueInputCallbackBlock)dispatch.callback;
    AudioTimeStamp startTime = {0};
    if (inStartTime != NULL) {
        startTime = *inStartTime;
    }
    size_t bytes = inNumberPacketDescriptions * sizeof(AudioStreamPacketDescription);
    AudioStreamPacketDescription *descriptions = NULL;
    if (inPacketDescs != NULL && inNumberPacketDescriptions > 0) {
        descriptions = malloc(bytes);
        if (descriptions != NULL) {
            memcpy(descriptions, inPacketDescs, bytes);
        }
    }
    dispatch_async(dispatch.queue, ^{
        block(inAQ, inBuffer, inStartTime == NULL ? NULL : &startTime, inNumberPacketDescriptions, descriptions);
        free(descriptions);
    });
}

OSStatus AudioQueueNewOutputWithDispatchQueue(AudioQueueRef *outAQ, const AudioStreamBasicDescription *inFormat, UInt32 inFlags,
                                              dispatch_queue_t inCallbackDispatchQueue, AudioQueueOutputCallbackBlock inCallbackBlock)
{
    if (inCallbackDispatchQueue == NULL || inCallbackBlock == nil) {
        return kAudio_ParamError;
    }
    RevenantAudioQueueDispatch *dispatch = [[RevenantAudioQueueDispatch alloc] init];
    dispatch.queue = inCallbackDispatchQueue;
    dispatch.callback = inCallbackBlock;
    void *context = (__bridge_retained void *)dispatch;
    OSStatus status = AudioQueueNewOutput(inFormat, RevenantAudioQueueOutputCallback, context, NULL, NULL, inFlags, outAQ);
    if (status != noErr) {
        (void)(__bridge_transfer RevenantAudioQueueDispatch *)context;
    }
    return status;
}

OSStatus AudioQueueNewInputWithDispatchQueue(AudioQueueRef *outAQ, const AudioStreamBasicDescription *inFormat, UInt32 inFlags,
                                             dispatch_queue_t inCallbackDispatchQueue, AudioQueueInputCallbackBlock inCallbackBlock)
{
    if (inCallbackDispatchQueue == NULL || inCallbackBlock == nil) {
        return kAudio_ParamError;
    }
    RevenantAudioQueueDispatch *dispatch = [[RevenantAudioQueueDispatch alloc] init];
    dispatch.queue = inCallbackDispatchQueue;
    dispatch.callback = inCallbackBlock;
    void *context = (__bridge_retained void *)dispatch;
    OSStatus status = AudioQueueNewInput(inFormat, RevenantAudioQueueInputCallback, context, NULL, NULL, inFlags, outAQ);
    if (status != noErr) {
        (void)(__bridge_transfer RevenantAudioQueueDispatch *)context;
    }
    return status;
}
