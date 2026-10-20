#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

static void revenant_deliver(dispatch_block_t block)
{
    if (!block)
        return;
    dispatch_async(dispatch_get_main_queue(), block);
}

#define REVENANT_SEND(instance, selector) ((id (*)(id, SEL))objc_msgSend)((instance), sel_registerName(selector))
#define REVENANT_SEND1(instance, selector, arg) ((id (*)(id, SEL, __typeof__(arg)))objc_msgSend)((instance), sel_registerName(selector), (arg))
#define REVENANT_SEND2(instance, selector, arg, arg2) ((id (*)(id, SEL, __typeof__(arg), __typeof__(arg2)))objc_msgSend)((instance), sel_registerName(selector), (arg), (arg2))
#define REVENANT_SEND_INT(instance, selector) ((CMPersistentTrackID (*)(id, SEL))objc_msgSend)((instance), sel_registerName(selector))
#define REVENANT_SEND_TIME(instance, selector, arg) ((CMTime (*)(id, SEL, __typeof__(arg)))objc_msgSend)((instance), sel_registerName(selector), (arg))

@interface AVAsset (RevenantAsyncLoading15)
@end

@implementation AVAsset (RevenantAsyncLoading15)

- (void)loadTracksWithMediaType:(AVMediaType)mediaType completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = REVENANT_SEND1(self, "tracksWithMediaType:", mediaType);
    revenant_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

- (void)loadTrackWithTrackID:(CMPersistentTrackID)trackID completionHandler:(void (^)(AVAssetTrack *track, NSError *error))handler
{
    void (^delivered)(AVAssetTrack *, NSError *) = [handler copy];
    AVAssetTrack *track = REVENANT_SEND1(self, "trackWithTrackID:", trackID);
    revenant_deliver(^{
        if (delivered)
            delivered(track, nil);
    });
}

- (void)loadTracksWithMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = REVENANT_SEND1(self, "tracksWithMediaCharacteristic:", mediaCharacteristic);
    revenant_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

- (void)findUnusedTrackIDWithCompletionHandler:(void (^)(CMPersistentTrackID trackID, NSError *error))handler
{
    void (^delivered)(CMPersistentTrackID, NSError *) = [handler copy];
    CMPersistentTrackID trackID = REVENANT_SEND_INT(self, "unusedTrackID");
    revenant_deliver(^{
        if (delivered)
            delivered(trackID, nil);
    });
}

- (void)loadMetadataForFormat:(AVMetadataFormat)format completionHandler:(void (^)(NSArray<AVMetadataItem *> *metadata, NSError *error))handler
{
    void (^delivered)(NSArray<AVMetadataItem *> *, NSError *) = [handler copy];
    NSArray<AVMetadataItem *> *metadata = REVENANT_SEND1(self, "metadataForFormat:", format);
    revenant_deliver(^{
        if (delivered)
            delivered(metadata, nil);
    });
}

- (void)loadMediaSelectionGroupForMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic completionHandler:(void (^)(AVMediaSelectionGroup *mediaSelectionGroup, NSError *error))handler
{
    void (^delivered)(AVMediaSelectionGroup *, NSError *) = [handler copy];
    AVMediaSelectionGroup *group = REVENANT_SEND1(self, "mediaSelectionGroupForMediaCharacteristic:", mediaCharacteristic);
    revenant_deliver(^{
        if (delivered)
            delivered(group, nil);
    });
}

- (void)loadChapterMetadataGroupsBestMatchingPreferredLanguages:(NSArray<NSString *> *)preferredLanguages completionHandler:(void (^)(NSArray<AVTimedMetadataGroup *> *metadataGroups, NSError *error))handler
{
    void (^delivered)(NSArray<AVTimedMetadataGroup *> *, NSError *) = [handler copy];
    NSArray<AVTimedMetadataGroup *> *groups = REVENANT_SEND1(self, "chapterMetadataGroupsBestMatchingPreferredLanguages:", preferredLanguages);
    revenant_deliver(^{
        if (delivered)
            delivered(groups, nil);
    });
}

- (void)loadChapterMetadataGroupsWithTitleLocale:(NSLocale *)locale containingItemsWithCommonKeys:(NSArray<NSString *> *)commonKeys completionHandler:(void (^)(NSArray<AVTimedMetadataGroup *> *metadataGroups, NSError *error))handler
{
    void (^delivered)(NSArray<AVTimedMetadataGroup *> *, NSError *) = [handler copy];
    NSArray<AVTimedMetadataGroup *> *groups = REVENANT_SEND2(self, "chapterMetadataGroupsWithTitleLocale:containingItemsWithCommonKeys:", locale, commonKeys);
    revenant_deliver(^{
        if (delivered)
            delivered(groups, nil);
    });
}

@end

@interface AVAssetTrack (RevenantAsyncLoading15)
@end

@implementation AVAssetTrack (RevenantAsyncLoading15)

- (void)loadMetadataForFormat:(AVMetadataFormat)format completionHandler:(void (^)(NSArray<AVMetadataItem *> *metadata, NSError *error))handler
{
    void (^delivered)(NSArray<AVMetadataItem *> *, NSError *) = [handler copy];
    NSArray<AVMetadataItem *> *metadata = REVENANT_SEND1(self, "metadataForFormat:", format);
    revenant_deliver(^{
        if (delivered)
            delivered(metadata, nil);
    });
}

- (void)loadSamplePresentationTimeForTrackTime:(CMTime)trackTime completionHandler:(void (^)(CMTime samplePresentationTime, NSError *error))handler
{
    void (^delivered)(CMTime, NSError *) = [handler copy];
    CMTime time = REVENANT_SEND_TIME(self, "samplePresentationTimeForTrackTime:", trackTime);
    revenant_deliver(^{
        if (delivered)
            delivered(time, nil);
    });
}

- (void)loadSegmentForTrackTime:(CMTime)trackTime completionHandler:(void (^)(AVAssetTrackSegment *segment, NSError *error))handler
{
    void (^delivered)(AVAssetTrackSegment *, NSError *) = [handler copy];
    AVAssetTrackSegment *segment = REVENANT_SEND1(self, "segmentForTrackTime:", trackTime);
    revenant_deliver(^{
        if (delivered)
            delivered(segment, nil);
    });
}

@end

@interface AVComposition (RevenantAsyncLoading15)
@end

@implementation AVComposition (RevenantAsyncLoading15)

- (void)loadTrackWithTrackID:(CMPersistentTrackID)trackID completionHandler:(void (^)(AVAssetTrack *track, NSError *error))handler
{
    void (^delivered)(AVAssetTrack *, NSError *) = [handler copy];
    AVAssetTrack *track = REVENANT_SEND1(self, "trackWithTrackID:", trackID);
    revenant_deliver(^{
        if (delivered)
            delivered(track, nil);
    });
}

- (void)loadTracksWithMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = REVENANT_SEND1(self, "tracksWithMediaCharacteristic:", mediaCharacteristic);
    revenant_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

- (void)loadTracksWithMediaType:(AVMediaType)mediaType completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = REVENANT_SEND1(self, "tracksWithMediaType:", mediaType);
    revenant_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

@end

@interface AVMutableComposition (RevenantAsyncLoading15)
@end

@implementation AVMutableComposition (RevenantAsyncLoading15)

- (void)loadTrackWithTrackID:(CMPersistentTrackID)trackID completionHandler:(void (^)(AVAssetTrack *track, NSError *error))handler
{
    void (^delivered)(AVAssetTrack *, NSError *) = [handler copy];
    AVAssetTrack *track = REVENANT_SEND1(self, "trackWithTrackID:", trackID);
    revenant_deliver(^{
        if (delivered)
            delivered(track, nil);
    });
}

- (void)loadTracksWithMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = REVENANT_SEND1(self, "tracksWithMediaCharacteristic:", mediaCharacteristic);
    revenant_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

- (void)loadTracksWithMediaType:(AVMediaType)mediaType completionHandler:(void (^)(NSArray<AVAssetTrack *> *tracks, NSError *error))handler
{
    void (^delivered)(NSArray<AVAssetTrack *> *, NSError *) = [handler copy];
    NSArray<AVAssetTrack *> *tracks = REVENANT_SEND1(self, "tracksWithMediaType:", mediaType);
    revenant_deliver(^{
        if (delivered)
            delivered(tracks, nil);
    });
}

@end

@interface AVURLAsset (RevenantAsyncLoading15)
@end

@implementation AVURLAsset (RevenantAsyncLoading15)

- (void)findCompatibleTrackForCompositionTrack:(AVAssetTrack *)compositionTrack completionHandler:(void (^)(AVAssetTrack *track, NSError *error))handler
{
    void (^delivered)(AVAssetTrack *, NSError *) = [handler copy];
    AVAssetTrack *track = REVENANT_SEND1(self, "compatibleTrackForCompositionTrack:", compositionTrack);
    revenant_deliver(^{
        if (delivered)
            delivered(track, nil);
    });
}

@end
