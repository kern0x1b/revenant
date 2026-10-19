// The five property-key constants: that each is the global the header declares and not a method, and
// that a key read through it is the same value the getter reads.
#import "MPMediaItemStandin.h"

@implementation MPMediaItem
{
    NSDictionary *properties;
}
- (void)charon_set_properties:(NSDictionary *)properties { self->properties = properties; }
- (id)valueForProperty:(NSString *)property { return self->properties[property]; }
@end

#define CHARON_MEDIAPLAYER_STANDIN 1
#include "MPMediaItem70.m"
#include "MPMediaItem92.m"
#include "MPMediaItem100.m"
#include "MPMediaItem103.m"
#include "MPMediaItem145.m"

static int failures = 0;

static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    NSDictionary *given = @{@"isExplicit": @YES, @"hasProtectedAsset": @YES, @"dateAdded": @1000,
                            @"playbackStoreID": @"store", @"isPreorder": @YES};
    MPMediaItem *item = [[MPMediaItem alloc] init];
    [item charon_set_properties:given];
    check("MPMediaItemPropertyIsExplicit is the key the getter reads",
          [[item valueForProperty:MPMediaItemPropertyIsExplicit] boolValue] == item.isExplicitItem,
          MPMediaItemPropertyIsExplicit.UTF8String);
    check("MPMediaItemPropertyHasProtectedAsset is the key the getter reads",
          [[item valueForProperty:MPMediaItemPropertyHasProtectedAsset] boolValue] == item.hasProtectedAsset,
          MPMediaItemPropertyHasProtectedAsset.UTF8String);
    check("MPMediaItemPropertyDateAdded is the key the getter reads",
          [[item valueForProperty:MPMediaItemPropertyDateAdded] isEqual:item.dateAdded],
          MPMediaItemPropertyDateAdded.UTF8String);
    check("MPMediaItemPropertyPlaybackStoreID is the key the getter reads",
          [[item valueForProperty:MPMediaItemPropertyPlaybackStoreID] isEqual:item.playbackStoreID],
          MPMediaItemPropertyPlaybackStoreID.UTF8String);
    check("MPMediaItemPropertyIsPreorder is the key the getter reads",
          [[item valueForProperty:MPMediaItemPropertyIsPreorder] boolValue] == item.isPreorder,
          MPMediaItemPropertyIsPreorder.UTF8String);
    if (failures) { printf("constants: %d RED\n", failures); return 1; }
    printf("constants: OK (0 failures)\n");
    return 0;
}
