#import "CharonAVMetrics18.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>
#import "../../../c/charon-coding/files/CharonCoding.h"

// AVFoundation's metric event surface, one release's worth: an object may only hold API of one release,
// and which release that is was MEASURED - all sixteen classes below are first EXPORTED by the 18.0 cache
// (tools/symbol-first-release.lua over the held ladder, one `_OBJC_CLASS_$_` symbol per class, sixteen of
// them at 18.0). The two properties each variant-switch class gained at iOS 26 and the
// AVMetricMediaRendition class itself are in AVFoundationMetrics26.m, in the 26.0 band.

// ---------------------------------------------------------------------------------------------
// AVMetricEventStream
//
// This is the one class here with behaviour of its own, and it is the whole of what the header
// describes: a set of publishers, one subscriber with a queue, and the set of event classes the
// subscriber asked for. The two BOOL returns are answered by the header's own rules rather than always
// YES, so the answers are real:
//
//   -addPublisher:            NO when the argument does not conform to AVMetricEventStreamPublisher, and
//                             NO when the same publisher is already in the set. Both are checkable here
//                             and both are what the header's type requirement on the publisher is for,
//                             namely conformance to AVMetricEventStreamPublisher.
//   -setSubscriber:queue:     NO when the argument does not conform to AVMetricEventStreamSubscriber,
//                             and NO when a subscriber is already set. A nil queue is allowed by the
//                             header and is kept as nil.
//
// What the stream does NOT do is deliver anything, and that is a real limit rather than a missing
// piece: on this port's minimum release there is nothing that reports metrics. The publisher protocol is
// empty - it has no method at all in 26.2 - so there is no call to hand an event in, and no
// AVPlayerItem on iOS 6.1.3 raises any of the notifications these events are built from. So the stream
// keeps the subscription the caller asked for and the subscriber it was given, and the subscriber's
// -publisher:didReceiveEvent: is never called by this port. Every event class below exists, with the
// members the header declares, and is never constructed by anything here.
// ---------------------------------------------------------------------------------------------
@interface AVMetricEventStream ()
{
    // A plain NSMutableSet of the publisher objects, held by pointer identity: two equal publishers are
    // still two publishers, and -isEqual: on an AVFoundation object of the caller's own class is not
    // this port's business. NSPointerFunctionsOpaquePersonality would be wrong for the same reason, so
    // the set is built with the default personality and the identity check is explicit below.
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
    // `id<AVMetricEventStreamPublisher>` does not declare -conformsToProtocol:, which comes from the
    // NSObject protocol, so the check is made on an untyped id rather than on the qualified one.
    id candidate = publisher;
    if (candidate == nil || ![candidate conformsToProtocol:@protocol(AVMetricEventStreamPublisher)]) {
        return NO;
    }
    for (id existing in _publishers) {
        if (existing == publisher) {
            // The same publisher twice is not a second subscription, and the header gives no way to
            // remove one, so adding it again would leave a set the caller cannot shrink.
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
        // One subscriber at a time: the header's setter takes a single delegate and there is no way to
        // remove one, so replacing it silently would leave the first one believing it is still the
        // subscriber for events it will never be given.
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
        // The header says "Type of metric event class to subscribe to". A class that is not one is not
        // an error the header describes - it has no return value - so nothing is stored and the
        // subscription set stays a set of metric event classes.
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
    // Every class this port carries that is an AVMetricEvent, taken by name and asked of the runtime
    // rather than written out as a list of sixteen, so a class added to this file is subscribed by
    // -subscribeToAllMetricEvents without a second edit here and a class the port does not carry cannot
    // be subscribed by accident.
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

// ---------------------------------------------------------------------------------------------
// The event classes
//
// Each is the header's own declaration and nothing else: the header's properties are @property
// (readonly), so clang synthesises the ivar and the getter for each one, and an event that nothing has
// constructed reads the zero the header's own defaults describe:
//
//   date        the moment the instance was created - a real measurement, taken where the object exists
//   mediaTime   CMTimeMake(0, 1), which is the zero of the timeline: this port observes no media time
//   sessionID   nil, which is what the header documents for "If not available, value is nil"
//
// +new and -init answer through NSObject, which the release has; the header marks them
// AV_INIT_UNAVAILABLE, so an application written against a newer SDK cannot reach them either, and the
// port is no more permissive than Apple about that in any row.
//
// AVMetricDownloadSummaryEvent is NOT here: the 18.0 cache exports no _OBJC_CLASS_$_AVMetricDownloadSummaryEvent,
// so nothing measures it at 18.0 and it falls back to the header's own annotation, which 26.2 writes
// `ios(18)` - without the minor - while the cache measures its sixteen siblings at 18.0. relcheck.lua then
// reads one object as holding two releases and refuses it:
//
//   AVFoundationMetrics18.m defines AVMetricDownloadSummaryEvent from iOS 18 and AVMetricContentKeyRequestEvent
//   ... from iOS 18.0; an object carries API that arrived in one release, so split it
//
// It and its six members are in AVFoundationMetrics18b.m, which is therefore the 18 band and this the 18.0
// band. The two spellings are Apple's, not the port's: 26.2 annotates this one declaration `ios(18)`.
//
// The three rendition properties each variant-switch class gained at iOS 26 - videoRendition,
// audioRendition and subtitleRendition - are NOT in this object. They are in AVFoundationMetrics26.m as a
// category on each of the two classes, because a property is API of the release it arrived in and this
// object is the 18.0 band; a category adds a selector to a class the 18.0 object defines, and
// charon_collect installs it where the class does not already answer it, which is exactly the case here.
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

// NSSecureCoding. The header declares the conformance, so without the three methods below an archive of one
// of these events would carry nothing at all - a silent wrong answer rather than a crash - and clang says so
// on this class:
//
//   method 'supportsSecureCoding' in protocol 'NSSecureCoding' not implemented
//   method 'encodeWithCoder:' in protocol 'NSCoding' not implemented
//   method 'initWithCoder:' in protocol 'NSCoding' not implemented
//
// They are here ONCE, on the root of the hierarchy, and every one of the sixteen subclasses inherits all
// three: none of them declares the conformance itself, so a second copy would be six identical methods.
//
// Encoding goes through packages/c/charon-coding/files/CharonCoding.h, whose walker reads the class's own
// ivar list through the runtime from the object's class up to NSObject - so a subclass carries its parent's
// state without either of them naming it, and a property added to a class later is carried by the same code
// rather than by an edit to an archive method, which would then be one list instead of the class.
//
// The initialiser is the superclass's own -init written out, because the header marks this class's -init
// AV_INIT_UNAVAILABLE and a file that reads the header cannot spell [super init] for it.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // charon_intents_decode writes the ivars this object was archived from, so it must NOT go through
    // -init: that would stamp the decode time over the archived date and put CMTimeMake(0, 1) back over an
    // archived mediaTime. The host round trip in tests/backports/host/avf-globals/coding.m is what says so.
    if ((self = charon_intents_super_init(self, [NSObject class]))) {
        charon_intents_decode(self, coder);
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

// @dynamic, because these three are declared by the header but carried by the 26.0 object: without it
// clang synthesizes a getter here and the registry then finds an 18.0 object answering a selector that
// arrived at 26.0 - and the 26.0 category's own accessor has nothing to add.
@dynamic videoRendition, audioRendition, subtitleRendition;

@synthesize fromVariant = _fromVariant;
@synthesize toVariant = _toVariant;
@synthesize loadedTimeRanges = _loadedTimeRanges;
@synthesize didSucceed = _didSucceed;
@end

@implementation AVMetricPlayerItemVariantSwitchStartEvent

// @dynamic, because these three are declared by the header but carried by the 26.0 object: without it
// clang synthesizes a getter here and the registry then finds an 18.0 object answering a selector that
// arrived at 26.0 - and the 26.0 category's own accessor has nothing to add.
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
