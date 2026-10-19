#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <AVFoundation/AVFoundation.h>
#endif
#import <objc/runtime.h>

#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface AVPlayerItem : NSObject
@end
@interface AVPlayerItem (CharonMPAdditions)
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *nowPlayingInfo;
@end
#endif

static const void *charon_avplayeritem_now_playing_info_key = &charon_avplayeritem_now_playing_info_key;

@implementation AVPlayerItem (CharonMPAdditions)

- (nullable NSDictionary<NSString *, id> *)nowPlayingInfo {
    return objc_getAssociatedObject(self, charon_avplayeritem_now_playing_info_key);
}

- (void)setNowPlayingInfo:(nullable NSDictionary<NSString *, id> *)nowPlayingInfo {
    objc_setAssociatedObject(self, charon_avplayeritem_now_playing_info_key, nowPlayingInfo,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
