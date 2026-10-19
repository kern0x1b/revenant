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
