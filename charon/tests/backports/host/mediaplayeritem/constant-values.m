// What this Mac's own MediaPlayer says each MPMediaItem property constant is, read and nothing else:
// no library, no query, no item - the constants are `NSString * const` data symbols, so linking against
// the framework answers the question the port's convention has been standing in for.
//
// The older constants are here as the witness: the port already carries those members, so if the host's
// values follow "the constant is the property's own name" then the convention holds and the five new
// values can be measured rather than assumed, and if they do not, the host is the authority and the
// port's list follows it.
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
