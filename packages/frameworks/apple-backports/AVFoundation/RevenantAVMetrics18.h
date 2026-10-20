#if !__has_include(<AVFCore/AVMetrics.h>)
#ifndef AVMETRICS_H
#define AVMETRICS_H

#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AVFoundation/AVContentKeySession.h>
#import <AVFoundation/AVAssetVariant.h>

NS_ASSUME_NONNULL_BEGIN

@class AVMetricEvent;

API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@protocol AVMetricEventStreamPublisher
@end

NS_REFINED_FOR_SWIFT
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@protocol AVMetricEventStreamSubscriber

- (void)publisher:(id<AVMetricEventStreamPublisher>)publisher didReceiveEvent:(AVMetricEvent *)event;
@end

NS_REFINED_FOR_SWIFT
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricEventStream : NSObject 

AV_INIT_UNAVAILABLE

+ (instancetype)eventStream;

- (BOOL)addPublisher:(id<AVMetricEventStreamPublisher>)publisher;

- (BOOL)setSubscriber:(id<AVMetricEventStreamSubscriber>)subscriber queue:(nullable dispatch_queue_t)queue;

- (void)subscribeToMetricEvent:(Class)metricEventClass;

- (void)subscribeToMetricEvents:(NSArray<Class> *)metricEventClasses;

- (void)subscribeToAllMetricEvents;

@end

#pragma mark - Base class -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricEvent : NSObject <NSSecureCoding>
AV_INIT_UNAVAILABLE

@property (readonly) NSDate *date;

@property (readonly) CMTime mediaTime;

@property (readonly, nullable) NSString *sessionID;

@end

#pragma mark - Error Event -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricErrorEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly) BOOL didRecover;

@property (readonly) NSError *error;
@end

#pragma mark - Resource Request Event -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricMediaResourceRequestEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly, nullable) NSURL *url;

@property (readonly, nullable) NSString *serverAddress;

@property (readonly) NSDate *requestStartTime;

@property (readonly) NSDate *requestEndTime;

@property (readonly) NSDate *responseStartTime;

@property (readonly) NSDate *responseEndTime;

@property (readonly) NSRange byteRange;

@property (readonly, getter=wasReadFromCache) BOOL readFromCache;

@property (readonly, nullable) AVMetricErrorEvent *errorEvent;

@property (readonly, nullable) NSURLSessionTaskMetrics *networkTransactionMetrics;
@end

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricHLSPlaylistRequestEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly, nullable) NSURL *url;

@property (readonly) BOOL isMultivariantPlaylist;

@property (readonly) AVMediaType mediaType;

@property (readonly, nullable) AVMetricMediaResourceRequestEvent *mediaResourceRequestEvent;
@end

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricHLSMediaSegmentRequestEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly, nullable) NSURL *url;

@property (readonly) BOOL isMapSegment;

@property (readonly) AVMediaType mediaType;

@property (readonly) NSRange byteRange;

@property (readonly) NSURL *indexFileURL;

@property (readonly) NSTimeInterval segmentDuration;

@property (readonly, nullable) AVMetricMediaResourceRequestEvent *mediaResourceRequestEvent;
@end

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricContentKeyRequestEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly) AVContentKeySpecifier *contentKeySpecifier;

@property (readonly) AVMediaType mediaType;

@property (readonly) BOOL isClientInitiated;

@property (readonly, nullable) AVMetricMediaResourceRequestEvent *mediaResourceRequestEvent;
@end

#pragma mark - Likely To Keep Up Events -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemLikelyToKeepUpEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly, nullable) AVAssetVariant *variant;

@property (readonly) NSTimeInterval timeTaken;

@property (readonly) NSArray<NSValue *> *loadedTimeRanges NS_REFINED_FOR_SWIFT;

@end

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemInitialLikelyToKeepUpEvent : AVMetricPlayerItemLikelyToKeepUpEvent
AV_INIT_UNAVAILABLE

@property (readonly) NSArray <AVMetricHLSPlaylistRequestEvent *> *playlistRequestEvents;

@property (readonly) NSArray <AVMetricHLSMediaSegmentRequestEvent *> *mediaSegmentRequestEvents;

@property (readonly) NSArray <AVMetricContentKeyRequestEvent *> *contentKeyRequestEvents;

@end

#pragma mark - Rate Change Events -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemRateChangeEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly) double rate;

@property (readonly) double previousRate;

@property (readonly, nullable) AVAssetVariant *variant;

@end

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemStallEvent : AVMetricPlayerItemRateChangeEvent
AV_INIT_UNAVAILABLE

@end

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemSeekEvent : AVMetricPlayerItemRateChangeEvent
AV_INIT_UNAVAILABLE

@end

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemSeekDidCompleteEvent : AVMetricPlayerItemRateChangeEvent
AV_INIT_UNAVAILABLE

@property (readonly) BOOL didSeekInBuffer;

@end

#pragma mark - Variant Change Event -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0))
@interface AVMetricMediaRendition : NSObject <NSSecureCoding>
AV_INIT_UNAVAILABLE

@property (readonly, nullable) NSString *stableID;

@property (readonly, nullable) NSURL *URL;
@end

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemVariantSwitchEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly, nullable) AVAssetVariant *fromVariant;

@property (readonly) AVAssetVariant *toVariant;

@property (readonly) NSArray<NSValue *> *loadedTimeRanges NS_REFINED_FOR_SWIFT;

@property (readonly) AVMetricMediaRendition *videoRendition API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0));

@property (readonly) AVMetricMediaRendition *audioRendition API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0));

@property (readonly) AVMetricMediaRendition *subtitleRendition API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0));

@property (readonly) BOOL didSucceed;
@end

#pragma mark - Variant Switch Start Event -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemVariantSwitchStartEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly, nullable) AVAssetVariant *fromVariant;

@property (readonly) AVAssetVariant *toVariant;

@property (readonly) NSArray<NSValue *> *loadedTimeRanges NS_REFINED_FOR_SWIFT;

@property (readonly) AVMetricMediaRendition *videoRendition API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0));

@property (readonly) AVMetricMediaRendition *audioRendition API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0));

@property (readonly) AVMetricMediaRendition *subtitleRendition API_AVAILABLE(macos(26.0), ios(26.0), tvos(26.0), watchos(26.0));
@end

#pragma mark - Playback Summary Event -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricPlayerItemPlaybackSummaryEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly, nullable) AVMetricErrorEvent *errorEvent;

@property (readonly) NSInteger recoverableErrorCount;

@property (readonly) NSInteger stallCount;

@property (readonly) NSInteger variantSwitchCount;

@property (readonly) NSInteger playbackDuration;

@property (readonly) NSInteger mediaResourceRequestCount;

@property (readonly) NSTimeInterval timeSpentRecoveringFromStall;

@property (readonly) NSTimeInterval timeSpentInInitialStartup;

@property (readonly) NSInteger timeWeightedAverageBitrate;

@property (readonly) NSInteger timeWeightedPeakBitrate;

@end

#pragma mark - Download Summary Event -

NS_SWIFT_SENDABLE
API_AVAILABLE(macos(15), ios(18), tvos(18), watchos(11))
@interface AVMetricDownloadSummaryEvent : AVMetricEvent
AV_INIT_UNAVAILABLE

@property (readonly, nullable) AVMetricErrorEvent *errorEvent;

@property (readonly) NSInteger recoverableErrorCount;

@property (readonly) NSInteger mediaResourceRequestCount;

@property (readonly) NSInteger bytesDownloadedCount;

@property (readonly) NSTimeInterval downloadDuration;

@property (readonly) NSArray<AVAssetVariant *> *variants;

@end

NS_ASSUME_NONNULL_END

#endif

#else
#import <AVFCore/AVMetrics.h>
#endif
