//  The 16.4 SDK's declarations for the two 11.0 render classes, as the port's three objects compose over
//  them, and nothing else.
//
//  What 6.1.3 carries is measured, not assumed: tools/corpus/objc-inventory.lua over the armv7 caches of
//  6.1.3 and 4.3 lists no AVSampleBufferAudioRenderer, no AVSampleBufferRenderSynchronizer and no
//  AVQueuedSampleBufferRendering protocol among that release's classes and protocols (the command, its
//  output and the control - AVCaptureDevice with 100 instance selectors at 6.1.3 - are in
//  packages/a/apple-backports/facts/AVFoundation/Release11.md), and `strings -a` over the armv7 caches
//  answers 0 for every selector below. So there is nothing here for the release to declare and everything
//  here for the port to define, which is why this header declares the SDK's own shape of the two classes
//  rather than a smaller one: the port's objects and the harness both compile against the same
//  declarations a client of the port compiles against, and the port's definitions are what answer.
//
//  What the release DOES have, and what this header therefore does not declare as the port's to bring:
//
//    - CoreMedia's timebase: _CMTimebaseCreateWithMasterClock, _CMClockGetHostTimeClock,
//      _CMTimebaseSetTime, _CMTimebaseGetTime, _CMTimebaseSetRate, _CMTimebaseGetRate,
//      _CMTimebaseSetRateAndAnchorTime, _CMTimebaseSetMasterTimebase, _CMTimebaseSetMasterClock,
//      _CMTimebaseAddTimerDispatchSource, _CMTimebaseSetTimerDispatchSourceNextFireTime and
//      _CMTimebaseRemoveTimerDispatchSource, all read from 6.1.3's own CoreMedia export trie.
//    - AudioToolbox's queue: the 43 exports matching "AudioQueue" of 6.1.3's AudioToolbox, of which this
//      port's renderer uses ten.
//    - _AVFoundationErrorDomain, first held rung 4.0, which standin.m defines as the release defines it.
//
//  Two rules this header keeps, and both are the point of linking the port's real objects against it
//  instead of compiling a copy of them: it declares no member as implemented (the classes and the protocol
//  are declared and not implemented here, because nothing below 11.0 has them), and it declares every
//  member the 16.4 header does, so the port's objects cannot quietly implement a member that is not one of
//  the SDK's.
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

// AVQueuedSampleBufferRendering.h: the enum, the protocol and nothing of either class.
typedef NS_ENUM(NSInteger, AVQueuedSampleBufferRenderingStatus) {
    AVQueuedSampleBufferRenderingStatusUnknown = 0,
    AVQueuedSampleBufferRenderingStatusRendering = 1,
    AVQueuedSampleBufferRenderingStatusFailed = 2
};

@protocol AVQueuedSampleBufferRendering <NSObject>
@property (retain, readonly) __attribute__((NSObject)) CMTimebaseRef timebase;
- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)flush;
@property (readonly, getter=isReadyForMoreMediaData) BOOL readyForMoreMediaData;
- (void)requestMediaDataWhenReadyOnQueue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block;
- (void)stopRequestingMediaData;
@property (nonatomic, readonly) BOOL hasSufficientMediaDataForReliablePlaybackStart;
@end

// The release's own error domain and its "no more specific code" answer. AVFoundationErrorDomain is
// AVError.h:14 for 4.0, and AVErrorUnknown is the enum value beside it.
extern NSString *const AVFoundationErrorDomain;
enum { AVErrorUnknown = -11800 };

// AVAudioProcessingSettings.h in the 16.4 SDK: `typedef NSString * AVAudioTimePitchAlgorithm
// NS_STRING_ENUM`, and these four are the port's own constants from AVFoundationConstants70.m. The harness
// reads one back through the class under test, so the link needs the object that defines it.
typedef NSString *AVAudioTimePitchAlgorithm;
extern AVAudioTimePitchAlgorithm const AVAudioTimePitchAlgorithmSpectral;
extern AVAudioTimePitchAlgorithm const AVAudioTimePitchAlgorithmTimeDomain;

// The port's own notification names, from AVFoundationConstants110.m and AVFoundationConstants120.m.
extern NSString *const AVSampleBufferAudioRendererWasFlushedAutomaticallyNotification;
extern NSString *const AVSampleBufferAudioRendererFlushTimeKey;

// AVTime.h in the 16.4 SDK, and the release's own since 4.0 (tools/cache-index/first-rung.lua
// valueWithCMTime: and CMTimeValue both answer 4.0): the boundary times of
// -addBoundaryTimeObserverForTimes: are NSValues of a CMTime, and the port's objects read them back.
@interface NSValue (CharonCMTimeBox)
+ (NSValue *)valueWithCMTime:(CMTime)time;
- (CMTime)CMTimeValue;
@end

// The three properties below are declared here because the 16.4 SDK declares them and the port's rows
// answer them absent, NOT because this check needs them to exist: clang synthesises an ivar and a pair of
// accessors for every property an @interface declares and an @implementation does not mention, whatever
// its API_AVAILABLE says, and a synthesised accessor is a name the port claims and does not carry. The
// port's objects answer @dynamic for each, which is what makes -respondsToSelector: answer NO, and the
// four "absent:" rows of the differential are what hold them to that. Leaving them out of this header
// would have made the whole question invisible to this check, and it is visible in the real build.
@interface AVSampleBufferAudioRenderer : NSObject <AVQueuedSampleBufferRendering>
@property (nonatomic, readonly) AVQueuedSampleBufferRenderingStatus status;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, copy) AVAudioTimePitchAlgorithm audioTimePitchAlgorithm;
@property (nonatomic) float volume;
@property (nonatomic, getter=isMuted) BOOL muted;
@property (nonatomic) NSUInteger allowedAudioSpatializationFormats;
@property (nonatomic, copy, nullable) NSString *audioOutputDeviceUniqueID;
- (void)flushFromSourceTime:(CMTime)time completionHandler:(void (^)(BOOL flushSucceeded))completionHandler;
@end

@interface AVSampleBufferRenderSynchronizer : NSObject
@property (retain, readonly) __attribute__((NSObject)) CMTimebaseRef timebase;
@property (nonatomic, readwrite) float rate;
- (void)setRate:(float)rate time:(CMTime)time;
- (CMTime)currentTime;
- (void)setRate:(float)rate time:(CMTime)time atHostTime:(CMTime)hostTime;
@property (nonatomic) BOOL delaysRateChangeUntilHasSufficientMediaData;
@property (atomic, readonly) NSArray<__kindof id <AVQueuedSampleBufferRendering>> *renderers;
- (void)addRenderer:(id <AVQueuedSampleBufferRendering>)renderer;
- (void)removeRenderer:(id <AVQueuedSampleBufferRendering>)renderer
                atTime:(CMTime)time
      completionHandler:(nullable void (^)(BOOL didRemoveRenderer))completionHandler;
- (id)addPeriodicTimeObserverForInterval:(CMTime)interval
                                  queue:(nullable dispatch_queue_t)queue
                              usingBlock:(void (^)(CMTime time))block;
- (id)addBoundaryTimeObserverForTimes:(NSArray<NSValue *> *)times
                               queue:(nullable dispatch_queue_t)queue
                           usingBlock:(void (^)(void))block;
- (void)removeTimeObserver:(id)observer;
@end