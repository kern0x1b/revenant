// The contract for MPMediaItem's 8.0 group, compiled against the port's own source and a stand-in. The
// expected table is generated from the same list the getters and the facts rows come from.
#import "MPMediaItemStandin.h"
static char *const members[][3] = {
#include "members80.h"
};

@implementation MPMediaItem
{
    NSDictionary *properties;
}
- (void)charon_set_properties:(NSDictionary *)properties { self->properties = properties; }
- (id)valueForProperty:(NSString *)property { return self->properties[property]; }
@end

#define CHARON_MEDIAPLAYER_STANDIN 1
#include "MPMediaItem80.m"

static int failures = 0;

static void check(const char *what, int held, const char *expected, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, expected); }
    else { printf("  RED  %s: expected %s, got %s\n", what, expected, got); failures++; }
}

static const char *text(id value) { return value ? [[value description] UTF8String] : "nil"; }
static const char *number(NSUInteger value, int which) {
    static char text[2][32];
    snprintf(text[which], sizeof text[which], "%lu", (unsigned long)value);
    return text[which];
}

int main(void) {
    // One value per member, one per type the group carries, read back through the generated table.
    NSDictionary *given = @{@"albumPersistentID": @11, @"artistPersistentID": @12, @"albumArtistPersistentID": @13,
                            @"genrePersistentID": @14, @"composerPersistentID": @15, @"podcastPersistentID": @16,
                            @"albumTrackCount": @3, @"discCount": @1, @"beatsPerMinute": @128,
                            @"compilation": @YES, @"cloudItem": @NO, @"lyrics": @"words",
                            @"comments": @"note", @"userGrouping": @"group", @"assetURL": [NSURL URLWithString:@"file:///a"]};
    MPMediaItem *item = [[MPMediaItem alloc] init];
    [item charon_set_properties:given];
    const NSUInteger wanted[] = {11, 12, 13, 14, 15, 16, 3, 1, 128};
    for (size_t i = 0; i < sizeof members / sizeof *members; ++i) {
        const char *name = members[i][0];
        NSUInteger got = 0;
        if (strcmp(name, "albumPersistentID") == 0) { got = item.albumPersistentID.unsignedIntegerValue; }
        else if (strcmp(name, "artistPersistentID") == 0) { got = item.artistPersistentID.unsignedIntegerValue; }
        else if (strcmp(name, "albumArtistPersistentID") == 0) { got = item.albumArtistPersistentID.unsignedIntegerValue; }
        else if (strcmp(name, "genrePersistentID") == 0) { got = item.genrePersistentID.unsignedIntegerValue; }
        else if (strcmp(name, "composerPersistentID") == 0) { got = item.composerPersistentID.unsignedIntegerValue; }
        else if (strcmp(name, "podcastPersistentID") == 0) { got = item.podcastPersistentID.unsignedIntegerValue; }
        else if (strcmp(name, "albumTrackCount") == 0) { got = item.albumTrackCount; }
        else if (strcmp(name, "discCount") == 0) { got = item.discCount; }
        else if (strcmp(name, "beatsPerMinute") == 0) { got = item.beatsPerMinute; }
        else if (strcmp(name, "isCompilation") == 0) { check(name, item.isCompilation == YES, "1", item.isCompilation ? "1" : "0"); continue; }
        else if (strcmp(name, "isCloudItem") == 0) { check(name, item.isCloudItem == NO, "0", item.isCloudItem ? "1" : "0"); continue; }
        else if (strcmp(name, "lyrics") == 0) { check(name, [item.lyrics isEqual:@"words"], "words", text(item.lyrics)); continue; }
        else if (strcmp(name, "comments") == 0) { check(name, [item.comments isEqual:@"note"], "note", text(item.comments)); continue; }
        else if (strcmp(name, "userGrouping") == 0) { check(name, [item.userGrouping isEqual:@"group"], "group", text(item.userGrouping)); continue; }
        else if (strcmp(name, "assetURL") == 0) { check(name, [item.assetURL isEqual:[NSURL URLWithString:@"file:///a"]], "file:///a", text(item.assetURL)); continue; }
        check(name, got == wanted[i], number(wanted[i], 0), number(got, 1));
    }
    // A key the dictionary does not hold: nil, so every conversion answers its zero and nothing raises.
    MPMediaItem *empty = [[MPMediaItem alloc] init];
    [empty charon_set_properties:@{}];
    check("a missing key answers zero or nil",
          empty.albumTrackCount == 0 && empty.isCompilation == NO && empty.lyrics == nil && empty.assetURL == nil
          && empty.albumPersistentID == nil,
          "0, NO, nil, nil, nil", "other");
    if (failures) { printf("contract: %d RED\n", failures); return 1; }
    printf("contract: OK (0 failures)\n");
    return 0;
}
