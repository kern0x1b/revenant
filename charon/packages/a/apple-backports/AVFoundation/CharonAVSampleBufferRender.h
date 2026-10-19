// CharonAVSampleBufferRender.h - what the two 11.0 render classes say to each other, and nothing else.
//
// Both classes are the port's own: neither exists on 6.1.3 (0 hits for AVSampleBufferAudioRenderer and
// AVSampleBufferRenderSynchronizer in the release's own 113981-name selector set, and
// tools/corpus/objc-inventory.lua over the armv7 caches of 6.1.3 and 4.3 lists neither class nor the
// AVQueuedSampleBufferRendering protocol - the command, its output and its control are in
// facts/AVFoundation/Release11.md). The three objects of the family therefore talk to each other
// through the members the SDK header already declares, plus the seams below. Everything the
// synchronizer needs from a renderer beyond the protocol's own -timebase is here, and -timebase is a
// CMTimebaseRef, so the synchronizer slaves, stops and zeroes that clock with CoreMedia and needs no
// other way into a renderer it does not own.
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

// What the synchronizer asks of every renderer attached to it when its rate changes. The renderer
// answers the header's statement for AVSampleBufferAudioRendererWasFlushedAutomaticallyNotification, that a
// renderer may flush its enqueued media when the attached synchronizer's playback rate changes. It does so by
// discarding the media it holds and posting that
// notification, and only when it held any, which is what this Mac's own renderer answers for a renderer
// that holds none (measured, tests/backports/host/avf-samplerender11).
//
// It is declared on NSObject and not on the renderer's class because what the synchronizer holds is
// id<AVQueuedSampleBufferRendering>, and anything at all may conform to that protocol: the synchronizer
// asks through -respondsToSelector: before sending, and a conformer that does not implement it is a
// conformer that has nothing to do about a rate change. That is the answer for that receiver, not a
// failure to report.
@interface NSObject (CharonAVSampleBufferRenderInternal)
- (void)charon_renderSynchronizerDidChangeRate;
@end

// The synchronizer's own seams, used by its 12.0 and 14.5 objects and by its renderer list. Each one is
// a place the rate or the time changes, so that every renderer attached is told exactly once.
@interface AVSampleBufferRenderSynchronizer (CharonAVSampleBufferRenderSynchronizerInternal)
- (void)charon_setRate:(float)rate time:(CMTime)time hostTime:(CMTime)hostTime;
- (void)charon_clocksDidChange;
- (void)charon_removeRenderer:(id <AVQueuedSampleBufferRendering>)renderer;
- (dispatch_queue_t)charon_queueFor:(dispatch_queue_t)queue;
// For the two helper classes of AVSampleBufferRenderSynchronizer11.m, which hold an unretained owner and
// so reach the synchronizer by name rather than through its storage.
- (void)charon_addObserver:(id)observer;
- (void)charon_forgetRemoval:(id)removal;
@end