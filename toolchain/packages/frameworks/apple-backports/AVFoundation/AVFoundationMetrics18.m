#import "RevenantAVMetrics18.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>
#import "../../../runtimes/revenant-coding/files/RevenantCoding.h"

@interface AVMetricEventStream ()
{
    NSMutableSet *_publishers;
    NSMutableSet *_subscribedClasses;
    id<AVMetricEventStreamSubscriber> _subscriber;
    dispatch_queue_t _queue;
}
@end

@implementation AVMetricEventStream

+ (instancetype)eventStream
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _publishers = [[NSMutableSet alloc] init];
        _subscribedClasses = [[NSMutableSet alloc] init];
        _subscriber = nil;
        _queue = NULL;
    }
    return self;
}

- (BOOL)addPublisher:(id<AVMetricEventStreamPublisher>)publisher
{
    id candidate = publisher;
    if (candidate == nil || ![candidate conformsToProtocol:@protocol(AVMetricEventStreamPublisher)]) {
        return NO;
    }
    for (id existing in _publishers) {
        if (existing == publisher) {
            return NO;
        }
    }
    [_publishers addObject:publisher];
    return YES;
}

- (BOOL)setSubscriber:(id<AVMetricEventStreamSubscriber>)subscriber queue:(nullable dispatch_queue_t)queue
{
    id candidate = subscriber;
    if (candidate == nil || ![candidate conformsToProtocol:@protocol(AVMetricEventStreamSubscriber)]) {
        return NO;
    }
    if (_subscriber != nil && _subscriber != subscriber) {
        return NO;
    }
    _subscriber = subscriber;
    _queue = queue;
    return YES;
}

- (void)subscribeToMetricEvent:(Class)metricEventClass
{
    if (metricEventClass == Nil) {
        return;
    }
    if (![metricEventClass isSubclassOfClass:[AVMetricEvent class]]) {
        return;
    }
    [_subscribedClasses addObject:metricEventClass];
}

- (void)subscribeToMetricEvents:(NSArray<Class> *)metricEventClasses
{
    for (Class metricEventClass in metricEventClasses) {
        [self subscribeToMetricEvent:metricEventClass];
    }
}

- (void)subscribeToAllMetricEvents
{
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (classes == NULL) {
        return;
    }
    for (unsigned int index = 0; index < count; index++) {
        Class candidate = classes[index];
        NSString *name = NSStringFromClass(candidate);
        if ([name hasPrefix:@"AVMetric"] && [candidate isSubclassOfClass:[AVMetricEvent class]]) {
            [_subscribedClasses addObject:candidate];
        }
    }
    free(classes);
}

@end

@implementation AVMetricEvent

@synthesize date = _date;
@synthesize mediaTime = _mediaTime;
@synthesize sessionID = _sessionID;

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _date = [NSDate date];
        _mediaTime = CMTimeMake(0, 1);
        _sessionID = nil;
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = revenant_intents_super_init(self, [NSObject class]))) {
        revenant_intents_decode(self, coder);
    }
    return self;
}

@end

@implementation AVMetricErrorEvent

@synthesize didRecover = _didRecover;
@synthesize error = _error;
@end

@implementation AVMetricMediaResourceRequestEvent

@synthesize url = _url;
@synthesize serverAddress = _serverAddress;
@synthesize requestStartTime = _requestStartTime;
@synthesize requestEndTime = _requestEndTime;
@synthesize responseStartTime = _responseStartTime;
@synthesize responseEndTime = _responseEndTime;
@synthesize byteRange = _byteRange;
@synthesize readFromCache = _readFromCache;
@synthesize errorEvent = _errorEvent;
@synthesize networkTransactionMetrics = _networkTransactionMetrics;
@end

@implementation AVMetricHLSPlaylistRequestEvent

@synthesize url = _url;
@synthesize isMultivariantPlaylist = _isMultivariantPlaylist;
@synthesize mediaType = _mediaType;
@synthesize mediaResourceRequestEvent = _mediaResourceRequestEvent;
@end

@implementation AVMetricHLSMediaSegmentRequestEvent

@synthesize url = _url;
@synthesize isMapSegment = _isMapSegment;
@synthesize mediaType = _mediaType;
@synthesize byteRange = _byteRange;
@synthesize indexFileURL = _indexFileURL;
@synthesize segmentDuration = _segmentDuration;
@synthesize mediaResourceRequestEvent = _mediaResourceRequestEvent;
@end

@implementation AVMetricContentKeyRequestEvent

@synthesize contentKeySpecifier = _contentKeySpecifier;
@synthesize mediaType = _mediaType;
@synthesize isClientInitiated = _isClientInitiated;
@synthesize mediaResourceRequestEvent = _mediaResourceRequestEvent;
@end

@implementation AVMetricPlayerItemLikelyToKeepUpEvent

@synthesize variant = _variant;
@synthesize timeTaken = _timeTaken;
@synthesize loadedTimeRanges = _loadedTimeRanges;
@end

@implementation AVMetricPlayerItemInitialLikelyToKeepUpEvent

@synthesize playlistRequestEvents = _playlistRequestEvents;
@synthesize mediaSegmentRequestEvents = _mediaSegmentRequestEvents;
@synthesize contentKeyRequestEvents = _contentKeyRequestEvents;
@end

@implementation AVMetricPlayerItemRateChangeEvent

@synthesize rate = _rate;
@synthesize previousRate = _previousRate;
@synthesize variant = _variant;
@end

@implementation AVMetricPlayerItemStallEvent
@end

@implementation AVMetricPlayerItemSeekEvent
@end

@implementation AVMetricPlayerItemSeekDidCompleteEvent

@synthesize didSeekInBuffer = _didSeekInBuffer;
@end

@implementation AVMetricPlayerItemVariantSwitchEvent

@dynamic videoRendition, audioRendition, subtitleRendition;

@synthesize fromVariant = _fromVariant;
@synthesize toVariant = _toVariant;
@synthesize loadedTimeRanges = _loadedTimeRanges;
@synthesize didSucceed = _didSucceed;
@end

@implementation AVMetricPlayerItemVariantSwitchStartEvent

@dynamic videoRendition, audioRendition, subtitleRendition;

@synthesize fromVariant = _fromVariant;
@synthesize toVariant = _toVariant;
@synthesize loadedTimeRanges = _loadedTimeRanges;
@end

@implementation AVMetricPlayerItemPlaybackSummaryEvent

@synthesize errorEvent = _errorEvent;
@synthesize recoverableErrorCount = _recoverableErrorCount;
@synthesize stallCount = _stallCount;
@synthesize variantSwitchCount = _variantSwitchCount;
@synthesize playbackDuration = _playbackDuration;
@synthesize mediaResourceRequestCount = _mediaResourceRequestCount;
@synthesize timeSpentRecoveringFromStall = _timeSpentRecoveringFromStall;
@synthesize timeSpentInInitialStartup = _timeSpentInInitialStartup;
@synthesize timeWeightedAverageBitrate = _timeWeightedAverageBitrate;
@synthesize timeWeightedPeakBitrate = _timeWeightedPeakBitrate;
@end
