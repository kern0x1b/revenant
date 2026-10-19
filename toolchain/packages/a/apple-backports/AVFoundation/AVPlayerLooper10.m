#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#include <math.h>

#define CHARON_LOOPER_STATUS_UNKNOWN 0
#define CHARON_LOOPER_STATUS_READY 1
#define CHARON_LOOPER_STATUS_FAILED 2
#define CHARON_LOOPER_STATUS_CANCELLED 3

static const double charonLooperQueuedSeconds = 10.0;
static const NSInteger charonLooperUnknownLengthCopies = 3;

static void *charonLooperFirstStatusContext = &charonLooperFirstStatusContext;

__attribute__((objc_runtime_name("AVPlayerLooper")))
@interface CharonPlayerLooper : NSObject

+ (instancetype)playerLooperWithPlayer:(AVQueuePlayer *)player templateItem:(AVPlayerItem *)itemToLoop;
+ (instancetype)playerLooperWithPlayer:(AVQueuePlayer *)player templateItem:(AVPlayerItem *)itemToLoop timeRange:(CMTimeRange)loopRange;
- (instancetype)initWithPlayer:(AVQueuePlayer *)player templateItem:(AVPlayerItem *)itemToLoop timeRange:(CMTimeRange)loopRange;
- (void)disableLooping;

@property (nonatomic, readonly) NSInteger status;
@property (nonatomic, readonly, copy) NSError *error;
@property (nonatomic, readonly) NSInteger loopCount;
@property (nonatomic, readonly, copy) NSArray<AVPlayerItem *> *loopingPlayerItems;

@end

@implementation CharonPlayerLooper {
    AVQueuePlayer *_player;
    AVPlayerItem *_template;
    CMTimeRange _loopRange;
    CMTime _loopLength;
    NSMutableArray<AVPlayerItem *> *_copies;
    AVPlayerItem *_first;
    NSInteger _copyTarget;
    NSInteger _status;
    NSError *_error;
    NSInteger _loopCount;
    BOOL _observingFirst;
    BOOL _observingEnds;
}

+ (instancetype)playerLooperWithPlayer:(AVQueuePlayer *)player templateItem:(AVPlayerItem *)itemToLoop
{
    return [[self alloc] initWithPlayer:player templateItem:itemToLoop timeRange:kCMTimeRangeInvalid];
}

+ (instancetype)playerLooperWithPlayer:(AVQueuePlayer *)player templateItem:(AVPlayerItem *)itemToLoop timeRange:(CMTimeRange)loopRange
{
    return [[self alloc] initWithPlayer:player templateItem:itemToLoop timeRange:loopRange];
}

- (instancetype)initWithPlayer:(AVQueuePlayer *)player templateItem:(AVPlayerItem *)itemToLoop timeRange:(CMTimeRange)loopRange
{
    self = [super init];
    if (!self)
        return nil;
    _player = player;
    _template = itemToLoop;
    _loopRange = loopRange;
    _copies = [NSMutableArray array];
    _status = CHARON_LOOPER_STATUS_UNKNOWN;

    if (CMTIMERANGE_IS_VALID(loopRange))
        _loopLength = loopRange.duration;
    else if ([itemToLoop.asset statusOfValueForKey:@"duration" error:NULL] == AVKeyValueStatusLoaded)
        _loopLength = itemToLoop.asset.duration;
    else
        _loopLength = kCMTimeInvalid;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(charonItemDidPlayToEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    _observingEnds = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ [self charonBeginLooping]; });
    return self;
}

- (void)dealloc
{
    if (_observingFirst)
        [_first removeObserver:self forKeyPath:@"status" context:charonLooperFirstStatusContext];
    if (_observingEnds)
        [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger)status
{
    return _status;
}

- (NSError *)error
{
    return _error;
}

- (NSInteger)loopCount
{
    return _loopCount;
}

- (NSArray<AVPlayerItem *> *)loopingPlayerItems
{
    return [_copies copy];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != charonLooperFirstStatusContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ [self charonFirstChanged]; });
}

- (void)charonBeginLooping
{
    if (_status != CHARON_LOOPER_STATUS_UNKNOWN)
        return;
    double seconds = CMTIME_IS_VALID(_loopLength) ? CMTimeGetSeconds(_loopLength) : 0.0;
    if (seconds > 0.0)
        _copyTarget = (NSInteger)ceil(charonLooperQueuedSeconds / seconds);
    else
        _copyTarget = charonLooperUnknownLengthCopies;

    _first = [self charonMakeCopy];
    [_first addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew
                context:charonLooperFirstStatusContext];
    _observingFirst = YES;
    [self charonQueueCopy:_first];
}

- (void)charonFirstChanged
{
    if (_status != CHARON_LOOPER_STATUS_UNKNOWN)
        return;
    AVPlayerItemStatus firstStatus = _first.status;
    if (firstStatus == AVPlayerItemStatusReadyToPlay) {
        [self charonStopObservingFirst];
        _status = CHARON_LOOPER_STATUS_READY;
        while (_copies.count < (NSUInteger)_copyTarget)
            [self charonQueueCopy:[self charonMakeCopy]];
    } else if (firstStatus == AVPlayerItemStatusFailed) {
        [self charonStopObservingFirst];
        _error = _first.error;
        _status = CHARON_LOOPER_STATUS_FAILED;
        [_player removeItem:_first];
        [_copies removeAllObjects];
    }
}

- (void)charonStopObservingFirst
{
    if (!_observingFirst)
        return;
    _observingFirst = NO;
    [_first removeObserver:self forKeyPath:@"status" context:charonLooperFirstStatusContext];
}

- (AVPlayerItem *)charonMakeCopy
{
    AVPlayerItem *copy = [AVPlayerItem playerItemWithAsset:_template.asset];
    if (CMTIMERANGE_IS_VALID(_loopRange)) {
        copy.forwardPlaybackEndTime = CMTimeRangeGetEnd(_loopRange);
        [copy seekToTime:_loopRange.start];
    }
    return copy;
}

- (void)charonQueueCopy:(AVPlayerItem *)copy
{
    [_copies addObject:copy];
    [_player insertItem:copy afterItem:nil];
}

- (void)charonItemDidPlayToEnd:(NSNotification *)notification
{
    AVPlayerItem *item = notification.object;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![_copies containsObject:item])
            return;
        [_copies removeObject:item];
        _loopCount++;
        if (_status == CHARON_LOOPER_STATUS_READY)
            [self charonQueueCopy:[self charonMakeCopy]];
    });
}

- (void)disableLooping
{
    [self charonStopObservingFirst];
    _status = CHARON_LOOPER_STATUS_CANCELLED;
    AVPlayerItem *playing = _player.currentItem;
    NSMutableArray<AVPlayerItem *> *kept = [NSMutableArray array];
    for (AVPlayerItem *copy in _copies) {
        if (copy == playing) {
            [kept addObject:copy];
        } else {
            [_player removeItem:copy];
        }
    }
    _copies = kept;
}

@end
