#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif
#import <objc/message.h>

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
@interface MPMusicPlayerController : NSObject
- (void)prepareToPlay;
@end
@interface MPMusicPlayerController (Revenant101)
- (void)prepareToPlayWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler;
@end
#endif

@implementation MPMusicPlayerController (Revenant101)

- (void)prepareToPlayWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler {
    ((void (*)(id, SEL))objc_msgSend)(self, sel_registerName("prepareToPlay"));

    if (completionHandler) {
        completionHandler(nil);
    }
}

@end
