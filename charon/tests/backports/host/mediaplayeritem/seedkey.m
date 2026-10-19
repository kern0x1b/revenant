// The value Apple's own MediaPlayer holds for MPMediaPlaylistPropertySeedItems, read and nothing else:
// the constants are `NSString * const` data symbols, so linking the framework answers the question. This
// Mac HAS the framework; the 6.1.3 release does not export any of MediaPlayer's 36 constants, so the port
// carries the value itself and the only honest source for it is Apple's own copy.
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

static void show(const char *name, NSString *value) {
    printf("  %-38s %s\n", name, value ? value.UTF8String : "(nil)");
}

int main(void) {
    printf("the key this row needs, read from Apple's own framework:\n");
    show("MPMediaPlaylistPropertySeedItems", MPMediaPlaylistPropertySeedItems);
    printf("the two the port already carries, as the witness that the reader is live:\n");
    show("MPMediaPlaylistPropertyAuthorDisplayName", MPMediaPlaylistPropertyAuthorDisplayName);
    show("MPMediaPlaylistPropertyDescriptionText", MPMediaPlaylistPropertyDescriptionText);
    printf("control, negative, a key no framework has:\n");
    show("MPMediaPlaylistPropertyAKeyNoFrameworkHas", @"");
    return 0;
}
