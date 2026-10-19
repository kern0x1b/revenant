#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

static void show(const char *name, NSString *value) {
    printf("  %-38s %s\n", name, value ? value.UTF8String : "(nil)");
}

int main(void) {
    printf("the five the port carries now, by convention:\n");
    show("MPMediaItemPropertyIsExplicit", MPMediaItemPropertyIsExplicit);
    show("MPMediaItemPropertyHasProtectedAsset", MPMediaItemPropertyHasProtectedAsset);
    show("MPMediaItemPropertyDateAdded", MPMediaItemPropertyDateAdded);
    show("MPMediaItemPropertyPlaybackStoreID", MPMediaItemPropertyPlaybackStoreID);
    show("MPMediaItemPropertyIsPreorder", MPMediaItemPropertyIsPreorder);
    printf("the ones 6.1.3 already had, as the witness:\n");
    show("MPMediaItemPropertyTitle", MPMediaItemPropertyTitle);
    show("MPMediaItemPropertyAlbumTitle", MPMediaItemPropertyAlbumTitle);
    show("MPMediaItemPropertyIsCompilation", MPMediaItemPropertyIsCompilation);
    show("MPMediaItemPropertyIsCloudItem", MPMediaItemPropertyIsCloudItem);
    show("MPMediaItemPropertyAlbumTrackCount", MPMediaItemPropertyAlbumTrackCount);
    show("MPMediaItemPropertyAlbumTrackNumber", MPMediaItemPropertyAlbumTrackNumber);
    show("MPMediaItemPropertyDiscNumber", MPMediaItemPropertyDiscNumber);
    show("MPMediaItemPropertyComments", MPMediaItemPropertyComments);
    show("MPMediaItemPropertyAssetURL", MPMediaItemPropertyAssetURL);
    return 0;
}
