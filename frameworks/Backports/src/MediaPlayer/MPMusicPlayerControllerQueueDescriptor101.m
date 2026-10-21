#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPMusicPlayerController (RevenantQueueDescriptor101)

- (void)setQueueWithDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    if (!queueDescriptor) {
        return;
    }
    if ([queueDescriptor isKindOfClass:[MPMusicPlayerMediaItemQueueDescriptor class]]) {
        MPMusicPlayerMediaItemQueueDescriptor *media =
            (MPMusicPlayerMediaItemQueueDescriptor *)queueDescriptor;
        if (media.query) {
            [self setQueueWithQuery:media.query];
            return;
        }
        if (media.itemCollection) {
            [self setQueueWithItemCollection:media.itemCollection];
            return;
        }
        return;
    }
    if ([queueDescriptor isKindOfClass:[MPMusicPlayerStoreQueueDescriptor class]]) {
        return;
    }
}

- (void)appendQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    (void)queueDescriptor;
}

- (void)prependQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    (void)queueDescriptor;
}

@end

@interface MPSystemMusicPlayerController : MPMusicPlayerController
@end

@implementation MPSystemMusicPlayerController
@end

@implementation MPSystemMusicPlayerController (RevenantOpenToPlay11)

- (void)openToPlayQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    (void)queueDescriptor;
}

- (void)openToPlayQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor
               completionHandler:(void (^)(NSError *))completionHandler {
    (void)queueDescriptor;
    if (!completionHandler) {
        return;
    }
    completionHandler([NSError errorWithDomain:MPErrorDomain
                                         code:MPErrorUnknown
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"openToPlayQueueDescriptor: needs a system music player, "
                                                    @"which this release does not have"}]);
}

@end
