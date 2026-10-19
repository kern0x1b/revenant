#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

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

extern NSString *const AVFoundationErrorDomain;
enum { AVErrorUnknown = -11800 };

typedef NSString *AVAudioTimePitchAlgorithm;
extern AVAudioTimePitchAlgorithm const AVAudioTimePitchAlgorithmSpectral;
extern AVAudioTimePitchAlgorithm const AVAudioTimePitchAlgorithmTimeDomain;

extern NSString *const AVSampleBufferAudioRendererWasFlushedAutomaticallyNotification;
extern NSString *const AVSampleBufferAudioRendererFlushTimeKey;

@interface NSValue (RevenantCMTimeBox)
+ (NSValue *)valueWithCMTime:(CMTime)time;
- (CMTime)CMTimeValue;
@end

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
