#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface NSObject (CharonAVSampleBufferRenderInternal)
- (void)charon_renderSynchronizerDidChangeRate;
@end

@interface AVSampleBufferRenderSynchronizer (CharonAVSampleBufferRenderSynchronizerInternal)
- (void)charon_setRate:(float)rate time:(CMTime)time hostTime:(CMTime)hostTime;
- (void)charon_clocksDidChange;
- (void)charon_removeRenderer:(id <AVQueuedSampleBufferRendering>)renderer;
- (dispatch_queue_t)charon_queueFor:(dispatch_queue_t)queue;
- (void)charon_addObserver:(id)observer;
- (void)charon_forgetRemoval:(id)removal;
@end
