#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface NSObject (RevenantAVSampleBufferRenderInternal)
- (void)revenant_renderSynchronizerDidChangeRate;
@end

@interface AVSampleBufferRenderSynchronizer (RevenantAVSampleBufferRenderSynchronizerInternal)
- (void)revenant_setRate:(float)rate time:(CMTime)time hostTime:(CMTime)hostTime;
- (void)revenant_clocksDidChange;
- (void)revenant_removeRenderer:(id <AVQueuedSampleBufferRendering>)renderer;
- (dispatch_queue_t)revenant_queueFor:(dispatch_queue_t)queue;
- (void)revenant_addObserver:(id)observer;
- (void)revenant_forgetRemoval:(id)removal;
@end
