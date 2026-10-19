#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

static void charon_deliver(dispatch_block_t block)
{
    if (!block)
        return;
    dispatch_async(dispatch_get_main_queue(), block);
}

#define CHARON_SEND(instance, selector) ((id (*)(id, SEL))objc_msgSend)((instance), sel_registerName(selector))
#define CHARON_SEND1(instance, selector, arg) ((id (*)(id, SEL, __typeof__(arg)))objc_msgSend)((instance), sel_registerName(selector), (arg))
#define CHARON_SEND2(instance, selector, arg, arg2) ((id (*)(id, SEL, __typeof__(arg), __typeof__(arg2)))objc_msgSend)((instance), sel_registerName(selector), (arg), (arg2))
#define CHARON_SEND_INT(instance, selector) ((CMPersistentTrackID (*)(id, SEL))objc_msgSend)((instance), sel_registerName(selector))
#define CHARON_SEND_TIME(instance, selector, arg) ((CMTime (*)(id, SEL, __typeof__(arg)))objc_msgSend)((instance), sel_registerName(selector), (arg))

@interface AVAsset (CharonAsyncLoading15)
@end

@implementation AVAsset (CharonAsyncLoading15)

- (void)loadTracksWithMediaType:(AVMediaType)mediaType completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = CHARON_SEND1(self, "tracksWithMediaType:", mediaType);
    charon_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

- (void)loadTrackWithTrackID:(CMPersistentTrackID)trackID completionHandler:(void (^)(AVAssetTrack *track, NSError *error))handler
{
    void (^delivered)(AVAssetTrack *, NSError *) = [handler copy];
    AVAssetTrack *track = CHARON_SEND1(self, "trackWithTrackID:", trackID);
    charon_deliver(^{
        if (delivered)
            delivered(track, nil);
    });
}

- (void)loadTracksWithMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = CHARON_SEND1(self, "tracksWithMediaCharacteristic:", mediaCharacteristic);
    charon_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

- (void)findUnusedTrackIDWithCompletionHandler:(void (^)(CMPersistentTrackID trackID, NSError *error))handler
{
    void (^delivered)(CMPersistentTrackID, NSError *) = [handler copy];
    CMPersistentTrackID trackID = CHARON_SEND_INT(self, "unusedTrackID");
    charon_deliver(^{
        if (delivered)
            delivered(trackID, nil);
    });
}

- (void)loadMetadataForFormat:(AVMetadataFormat)format completionHandler:(void (^)(NSArray<AVMetadataItem *> *metadata, NSError *error))handler
{
    void (^delivered)(NSArray<AVMetadataItem *> *, NSError *) = [handler copy];
    NSArray<AVMetadataItem *> *metadata = CHARON_SEND1(self, "metadataForFormat:", format);
    charon_deliver(^{
        if (delivered)
            delivered(metadata, nil);
    });
}

- (void)loadMediaSelectionGroupForMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic completionHandler:(void (^)(AVMediaSelectionGroup *mediaSelectionGroup, NSError *error))handler
{
    void (^delivered)(AVMediaSelectionGroup *, NSError *) = [handler copy];
    AVMediaSelectionGroup *group = CHARON_SEND1(self, "mediaSelectionGroupForMediaCharacteristic:", mediaCharacteristic);
    charon_deliver(^{
        if (delivered)
            delivered(group, nil);
    });
}

- (void)loadChapterMetadataGroupsBestMatchingPreferredLanguages:(NSArray<NSString *> *)preferredLanguages completionHandler:(void (^)(NSArray<AVTimedMetadataGroup *> *metadataGroups, NSError *error))handler
{
    void (^delivered)(NSArray<AVTimedMetadataGroup *> *, NSError *) = [handler copy];
    NSArray<AVTimedMetadataGroup *> *groups = CHARON_SEND1(self, "chapterMetadataGroupsBestMatchingPreferredLanguages:", preferredLanguages);
    charon_deliver(^{
        if (delivered)
            delivered(groups, nil);
    });
}

- (void)loadChapterMetadataGroupsWithTitleLocale:(NSLocale *)locale containingItemsWithCommonKeys:(NSArray<NSString *> *)commonKeys completionHandler:(void (^)(NSArray<AVTimedMetadataGroup *> *metadataGroups, NSError *error))handler
{
    void (^delivered)(NSArray<AVTimedMetadataGroup *> *, NSError *) = [handler copy];
    NSArray<AVTimedMetadataGroup *> *groups = CHARON_SEND2(self, "chapterMetadataGroupsWithTitleLocale:containingItemsWithCommonKeys:", locale, commonKeys);
    charon_deliver(^{
        if (delivered)
            delivered(groups, nil);
    });
}

@end

@interface AVAssetTrack (CharonAsyncLoading15)
@end

@implementation AVAssetTrack (CharonAsyncLoading15)

- (void)loadMetadataForFormat:(AVMetadataFormat)format completionHandler:(void (^)(NSArray<AVMetadataItem *> *metadata, NSError *error))handler
{
    void (^delivered)(NSArray<AVMetadataItem *> *, NSError *) = [handler copy];
    NSArray<AVMetadataItem *> *metadata = CHARON_SEND1(self, "metadataForFormat:", format);
    charon_deliver(^{
        if (delivered)
            delivered(metadata, nil);
    });
}

- (void)loadSamplePresentationTimeForTrackTime:(CMTime)trackTime completionHandler:(void (^)(CMTime samplePresentationTime, NSError *error))handler
{
    void (^delivered)(CMTime, NSError *) = [handler copy];
    CMTime time = CHARON_SEND_TIME(self, "samplePresentationTimeForTrackTime:", trackTime);
    charon_deliver(^{
        if (delivered)
            delivered(time, nil);
    });
}

- (void)loadSegmentForTrackTime:(CMTime)trackTime completionHandler:(void (^)(AVAssetTrackSegment *segment, NSError *error))handler
{
    void (^delivered)(AVAssetTrackSegment *, NSError *) = [handler copy];
    AVAssetTrackSegment *segment = CHARON_SEND1(self, "segmentForTrackTime:", trackTime);
    charon_deliver(^{
        if (delivered)
            delivered(segment, nil);
    });
}

@end

@interface AVComposition (CharonAsyncLoading15)
@end

@implementation AVComposition (CharonAsyncLoading15)

- (void)loadTrackWithTrackID:(CMPersistentTrackID)trackID completionHandler:(void (^)(AVAssetTrack *track, NSError *error))handler
{
    void (^delivered)(AVAssetTrack *, NSError *) = [handler copy];
    AVAssetTrack *track = CHARON_SEND1(self, "trackWithTrackID:", trackID);
    charon_deliver(^{
        if (delivered)
            delivered(track, nil);
    });
}

- (void)loadTracksWithMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = CHARON_SEND1(self, "tracksWithMediaCharacteristic:", mediaCharacteristic);
    charon_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

- (void)loadTracksWithMediaType:(AVMediaType)mediaType completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = CHARON_SEND1(self, "tracksWithMediaType:", mediaType);
    charon_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

@end

@interface AVMutableComposition (CharonAsyncLoading15)
@end

@implementation AVMutableComposition (CharonAsyncLoading15)

- (void)loadTrackWithTrackID:(CMPersistentTrackID)trackID completionHandler:(void (^)(AVAssetTrack *track, NSError *error))handler
{
    void (^delivered)(AVAssetTrack *, NSError *) = [handler copy];
    AVAssetTrack *track = CHARON_SEND1(self, "trackWithTrackID:", trackID);
    charon_deliver(^{
        if (delivered)
            delivered(track, nil);
    });
}

- (void)loadTracksWithMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = CHARON_SEND1(self, "tracksWithMediaCharacteristic:", mediaCharacteristic);
    charon_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

- (void)loadTracksWithMediaType:(AVMediaType)mediaType completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = CHARON_SEND1(self, "tracksWithMediaType:", mediaType);
    charon_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

@end

@interface AVURLAsset (CharonAsyncLoading15)
@end

@implementation AVURLAsset (CharonAsyncLoading15)

- (void)findCompatibleTrackForCompositionTrack:(AVAssetTrack *)compositionTrack completionHandler:(void (^)(AVAssetTrack *track, NSError *error))handler
{
    void (^delivered)(AVAssetTrack *, NSError *) = [handler copy];
    AVAssetTrack *track = CHARON_SEND1(self, "compatibleTrackForCompositionTrack:", compositionTrack);
    charon_deliver(^{
        if (delivered)
            delivered(track, nil);
    });
}

@end
