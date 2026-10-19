#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

// The asynchronous loading API of iOS 15, on the asset classes the port already carries.
//
// Every method here has the same shape and the same cause: 15.0 split each synchronous accessor into
// a `load...` that takes a completion handler and does its work off the calling thread, and left the
// synchronous accessor in place. This release never had the split, and it already has every accessor
// the split is built from - measured on the armv7 caches of both band ends, selector by selector on
// the owning class rather than as a name somewhere in the image:
//
//   -[AVAsset tracksWithMediaType:]                                       4.0  6.1.3 yes  4.3 yes
//   -[AVAsset trackWithTrackID:]                                          4.0  6.1.3 yes  4.3 yes
//   -[AVAsset tracksWithMediaCharacteristic:]                            4.0  6.1.3 yes  4.3 yes
//   -[AVAsset unusedTrackID]                                              4.0  6.1.3 yes  4.3 yes
//   -[AVAsset metadataForFormat:]                                         4.0  6.1.3 yes  4.3 yes
//   -[AVAsset compatibleTrackForCompositionTrack:]                       4.0  6.1.3 yes  4.3 yes
//   -[AVAsset mediaSelectionGroupForMediaCharacteristic:]                 5.0  6.1.3 yes  4.3 no
//   -[AVAsset chapterMetadataGroupsWithTitleLocale:containingItemsWithCommonKeys:]
//                                                                       4.3  6.1.3 yes  4.3 yes
//   -[AVAsset chapterMetadataGroupsBestMatchingPreferredLanguages:]       6.0  6.1.3 yes  4.3 no
//   -[AVAssetTrack metadataForFormat:]                                    4.0  6.1.3 yes  4.3 yes
//   -[AVAssetTrack samplePresentationTimeForTrackTime:]                   4.0  6.1.3 yes  4.3 yes
//   -[AVAssetTrack segmentForTrackTime:]                                  4.0  6.1.3 yes  4.3 yes
//
// The three AVComposition methods and the three AVMutableComposition ones are the same three on
// AVAsset, inherited: AVComposition is a subclass of AVAsset on both band ends, so the accessors
// answer on a composition without AVComposition declaring them. -[AVURLAsset
// findCompatibleTrackForCompositionTrack:completionHandler:] is
// -[AVAsset compatibleTrackForCompositionTrack:] likewise.
//
// So a method here is the release's own accessor, its answer handed to the caller's block, and the
// handler called on the main queue so a caller that reads the result on the main thread finds it
// there. The handler is copied first: the block the caller passes is released when this method
// returns, and calling a released block is what turns this into a crash in the middle of playback.
//
// WHAT A CALLER GETS, and it is not nothing: the value is the release's own, not a placeholder, and
// the handler is always called exactly once, with a nil error, because the synchronous accessor has
// no failure of its own to report. What is NOT carried is the other half of the 15.0 contract - the
// caller cannot cancel the load, because there is nothing here to cancel and 15.0's
// -cancelLoading is not in this slice.
//
// -[AVAssetTrack loadAssociatedTracksOfType:completionHandler:] is deliberately NOT here: its
// accessor -associatedTracksOfType: first appears at 7.0 and no band end this port builds carries it,
// so registry/AVFoundation/absent_AVFoundation.json says absent naming that. Facts:
// facts/AVFoundation/AssetAsyncLoading.md.

static void charon_deliver(dispatch_block_t block)
{
    if (!block)
        return;
    dispatch_async(dispatch_get_main_queue(), block);
}

// Calls the release's own accessor by its real selector. It goes through objc_msgSend rather than a
// typed message because the 16.4 header this file compiles against does not declare these selectors
// on these classes' 15.0 spelling, and the accessor it does declare is the one being called here - so
// the port sends the selector the release answers, not one the compiler believes in.
//
// The cast carries the accessor's OWN return type, which is not always an object: -unusedTrackID
// answers a CMPersistentTrackID (a 32-bit integer) and -samplePresentationTimeForTrackTime: answers
// a CMTime, a 24-byte struct returned through a hidden pointer. Casting either to the object-returning
// `id (*)(id, SEL)` shape and reading the result as an object is undefined behaviour, and on armv7 it
// misreads the register or the sret pointer rather than trapping - so each of those two is cast to its
// own signature below and nothing else is.
//
// The macro also carries the accessor's ARGUMENTS, and it carries them by their own type rather than
// by a type written beside the call: CHARON_SEND1 and CHARON_SEND2 read __typeof__ of each argument
// they are given, so the signature the message is sent through is the one those arguments have and a
// call site cannot name a signature its own argument does not match. That is the whole point of the
// cast - the argument registers on armv7 are chosen by the cast's parameter types, so a cast that does
// not name an argument's type passes it in the wrong register and nothing reports it.
//
// The macro is therefore the WHOLE send: it supplies the receiver, the selector and every argument, and
// its expansion is the value of the expression. It does not yield a function pointer for the call site
// to call, because an expansion that is already a send has no room left for a trailing `(argument)` -
// that shape applied the argument to the RESULT of the send, which is not a function, and every one of
// those call sites failed with "called object type 'id' is not a function or function pointer".
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

// -loadSegmentForTrackTime:completionHandler: takes a CMTime argument and the accessor it calls
// takes one too, so both go through this cast: a 24-byte struct is passed by value in four registers
// on armv7 and the hidden-return pointer for the result moves the argument registers, so a message
// send whose signature does not name the struct type misplaces it.
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

// Each of the three calls the accessor on AVAsset, which is where the release puts it: AVComposition
// declares neither and inherits both. The call is sent to self, so it dispatches on the composition's
// own class and a subclass overriding the accessor is the one that answers.
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

// A mutable composition inherits from AVComposition, which inherits from AVAsset, so the accessor is
// three generations up and declared in none of them. The methods are declared again here rather than
// inherited from the AVComposition category above because this is a category on a subclass and
// Objective-C does not carry a superclass's category methods down: without these three, a
// composition built through +[AVMutableComposition composition] would not answer them.
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

// -compatibleTrackForCompositionTrack: is AVAsset's, and AVURLAsset is a subclass of AVAsset on both
// band ends, so the accessor answers on a URL asset without AVURLAsset declaring it.
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