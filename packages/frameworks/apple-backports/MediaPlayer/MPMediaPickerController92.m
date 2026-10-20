#import <Foundation/Foundation.h>
#if defined(REVENANT_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif
#import <objc/runtime.h>

#if defined(REVENANT_MEDIAPLAYER_STANDIN)
@interface MPMediaPickerController : NSObject
@property (nonatomic) BOOL showsCloudItems;
@end
@interface MPMediaPickerController (Revenant92)
@property (nonatomic) BOOL showsItemsWithProtectedAssets;
@end
#endif

static const void *revenant_mediaplayer_protected_assets_key = &revenant_mediaplayer_protected_assets_key;

@implementation MPMediaPickerController (Revenant92)

- (BOOL)showsItemsWithProtectedAssets {
    NSNumber *held = objc_getAssociatedObject(self, revenant_mediaplayer_protected_assets_key);
    return held ? [held boolValue] : YES;
}

- (void)setShowsItemsWithProtectedAssets:(BOOL)showsItemsWithProtectedAssets {
    objc_setAssociatedObject(self, revenant_mediaplayer_protected_assets_key,
                             [NSNumber numberWithBool:showsItemsWithProtectedAssets],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
