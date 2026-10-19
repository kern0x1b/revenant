// The contract for every MPMediaItem group the port carries: 7.0 in MPMediaItem70.m, and 8.0, 9.2, 10.0
// and 10.3 generated into their own files. The expected table for each is generated from the same list
// its getters and its facts rows come from, so check, mutants and code cannot drift. Compiled against the
// port's own sources and a stand-in, so this measures the port and not the Mac's MediaPlayer - which
// declares several of these already, and a category compiled against that would look like a clobber.
#import "MPMediaItemStandin.h"

static char *const members80[][3] = {
#include "members80.h"
};
static char *const members92[][3] = {
#include "members92.h"
};
static char *const members100[][3] = {
#include "members100.h"
};
static char *const members103[][3] = {
#include "members103.h"
};

@implementation MPMediaItem
{
    NSDictionary *properties;
}
- (void)charon_set_properties:(NSDictionary *)properties { self->properties = properties; }
- (id)valueForProperty:(NSString *)property { return self->properties[property]; }
@end

#define CHARON_MEDIAPLAYER_STANDIN 1
#include "MPMediaItem70.m"
#include "MPMediaItem80.m"
#include "MPMediaItem92.m"
#include "MPMediaItem100.m"
#include "MPMediaItem103.m"

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
    NSDate *added = [NSDate dateWithTimeIntervalSince1970:1000];
    NSDictionary *given = @{@"albumTrackNumber": @7, @"discNumber": @2, @"albumPersistentID": @11,
                            @"artistPersistentID": @12, @"albumArtistPersistentID": @13, @"genrePersistentID": @14,
                            @"composerPersistentID": @15, @"podcastPersistentID": @16, @"albumTrackCount": @3,
                            @"discCount": @1, @"beatsPerMinute": @128, @"isCompilation": @YES, @"isCloudItem": @YES,
                            @"lyrics": @"words", @"comments": @"note", @"userGrouping": @"group",
                            @"assetURL": [NSURL URLWithString:@"file:///a"], @"hasProtectedAsset": @YES,
                            @"dateAdded": added, @"isExplicit": @YES, @"playbackStoreID": @"store",
                            @"isPreorder": @YES};
    MPMediaItem *item = [[MPMediaItem alloc] init];
    [item charon_set_properties:given];
    // 7.0
    check("albumTrackNumber", item.albumTrackNumber == 7, "7", number(item.albumTrackNumber, 1));
    check("discNumber", item.discNumber == 2, "2", number(item.discNumber, 1));
    // 8.0, by type
    check("albumPersistentID", [item.albumPersistentID isEqual:@11], "11", text(item.albumPersistentID));
    check("albumTrackCount", item.albumTrackCount == 3, "3", number(item.albumTrackCount, 1));
    check("beatsPerMinute", item.beatsPerMinute == 128, "128", number(item.beatsPerMinute, 1));
    check("isCompilation", item.isCompilation == YES, "1", item.isCompilation ? "1" : "0");
    check("isCloudItem", item.isCloudItem == YES, "1", item.isCloudItem ? "1" : "0");
    check("lyrics", [item.lyrics isEqual:@"words"], "words", text(item.lyrics));
    check("comments", [item.comments isEqual:@"note"], "note", text(item.comments));
    check("userGrouping", [item.userGrouping isEqual:@"group"], "group", text(item.userGrouping));
    check("assetURL", [item.assetURL isEqual:[NSURL URLWithString:@"file:///a"]], "file:///a", text(item.assetURL));
    // 9.2
    check("hasProtectedAsset", item.hasProtectedAsset == YES, "1", item.hasProtectedAsset ? "1" : "0");
    // 10.0
    check("dateAdded", [item.dateAdded isEqual:added], "1000", text(item.dateAdded));
    check("isExplicitItem", item.isExplicitItem == YES, "1", item.isExplicitItem ? "1" : "0");
    // 10.3
    check("playbackStoreID", [item.playbackStoreID isEqual:@"store"], "store", text(item.playbackStoreID));
    check("isPreorder", item.isPreorder == YES, "1", item.isPreorder ? "1" : "0");
    // A key the dictionary does not hold: nil, so every conversion answers its zero and nothing raises.
    MPMediaItem *empty = [[MPMediaItem alloc] init];
    [empty charon_set_properties:@{}];
    check("a missing key answers zero or nil",
          empty.albumTrackCount == 0 && empty.hasProtectedAsset == NO && empty.dateAdded == nil
          && empty.playbackStoreID == nil && empty.albumPersistentID == nil,
          "0, NO, nil, nil, nil", "other");
    if (failures) { printf("contract: %d RED\n", failures); return 1; }
    printf("contract: OK (0 failures)\n");
    return 0;
}
