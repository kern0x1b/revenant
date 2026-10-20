#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <AVFoundation/AVFoundation.h>
#endif
#import <objc/runtime.h>

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
@interface AVPlayerItem : NSObject
@end
@interface AVPlayerItem (RevenantMPAdditions)
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *nowPlayingInfo;
@end
#endif

static const void *revenant_avplayeritem_now_playing_info_key = &revenant_avplayeritem_now_playing_info_key;

@implementation AVPlayerItem (RevenantMPAdditions)

- (nullable NSDictionary<NSString *, id> *)nowPlayingInfo {
    return objc_getAssociatedObject(self, revenant_avplayeritem_now_playing_info_key);
}

- (void)setNowPlayingInfo:(nullable NSDictionary<NSString *, id> *)nowPlayingInfo {
    objc_setAssociatedObject(self, revenant_avplayeritem_now_playing_info_key, nowPlayingInfo,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
