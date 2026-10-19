#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#include <math.h>

// AVPlayerLooper, iOS 10.0: loops one item on an AVQueuePlayer.
//
// **What the release has.** 6.1.3's AVQueuePlayer carries items, insertItem:afterItem:, removeItem: and
// removeAllItems, and posts AVPlayerItemDidPlayToEndTimeNotification when an item of its queue finishes. So a
// looper is a queue manager built from things the release has, but the class is not there: 6.1.3 and 4.3 export no
// _OBJC_CLASS_$_AVPlayerLooper (facts/AVFoundation/PlayerLooper10.md).
//
// **The class, under Apple's own name at run time.** The source names it CharonPlayerLooper, and the attribute
// gives it the runtime name AVPlayerLooper, as AVFoundation/AVMovie.m does for CharonMovie. Its surface is the
// iOS 10 declaration from the generator's IR (spec/AVFoundation/declarations.tsv): the two factories, the
// initializer with a time range, disableLooping, and the readonly status, error, loopCount and loopingPlayerItems.
// The iOS 17 initializer with an existing-items ordering is not here.
//
// **How a loop starts.** An AVPlayerItem becomes ready to play only once it is in a player: a template that is
// merely made, or whose asset has loaded its keys, stays Unknown. So the looper queues a first copy, on the next turn
// of the main queue (never inside the factory), and waits for that copy to be ready. The copy is the one the queue
// plays first; the rest are queued once it is ready.
//
// **What the looper does, as the host measured it** (tests/backports/host/avf-player-looper; facts file):
//  - nothing is queued when the looper is made; the first copy is queued after the factory returns;
//  - the looper queues copies of the template's asset, never the template itself, so that about ten seconds of
//    loop material is queued: a loop of 1.0 s gives 10 copies, 0.5 s gives 20, 0.25 s gives 40, 0.1 s gives 100;
//  - with no time range, the loop is the asset's duration if that duration is already known when the looper is
//    made; if it is not, the looper queues 3 copies, and that count is not revisited;
//  - each copy that ends counts one loop (loopCount), and the looper queues one fresh copy at the end of the queue,
//    so the queue stays at its count;
//  - a template that cannot be played makes the looper Failed, with the copy's error, and nothing stays queued;
//  - disableLooping makes the looper Cancelled at once, removes every queued copy but the one playing, and queues
//    no more; the copy that is playing still counts when it ends.
//
// **Status values** are AVPlayerLooperStatus's: 0 Unknown, 1 Ready, 2 Failed, 3 Cancelled (the IR's enum).
//
// **What a copy carries.** A new AVPlayerItem on the template's asset. A time range sets the copy's forward playback
// end and seeks it to the range start (measured: a range from 0.5 s of length 0.5 s loops the second half). The
// template's own settings (audio mix, video composition and the rest) are not copied, and the host's copies were not
// checked for them, so the port claims none of them (facts/AVFoundation/PlayerLooper10.md).
//
// Nothing here replaces a release method. The class is new, and the release has none of it to call.

#define CHARON_LOOPER_STATUS_UNKNOWN 0
#define CHARON_LOOPER_STATUS_READY 1
#define CHARON_LOOPER_STATUS_FAILED 2
#define CHARON_LOOPER_STATUS_CANCELLED 3

// The seconds of loop material the looper keeps queued, and the copies it queues when the loop length is unknown.
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
    // The copies the looper queued and that have not yet ended, in queue order. The one playing is among them.
    NSMutableArray<AVPlayerItem *> *_copies;
    // The first copy, whose readiness starts the loop.
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

    // The loop length is read once, here: the range if one was given, else the asset's duration if the asset has
    // loaded its duration key. A duration that is only synchronously estimated does not count: the host gives three
    // copies for that case and ten once the key is loaded.
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

// The loop starts once: the first copy is queued, and the loop waits for it to be ready to play.
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
        // Keep the queue full, unless the looper has been told to stop.
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
