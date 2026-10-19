#import <Foundation/Foundation.h>

@class MPContentItem;
@interface MPMediaItem : NSObject
- (id)valueForProperty:(NSString *)property;
@end
@interface MPMediaPlaylist : NSObject
- (id)valueForProperty:(NSString *)property;
@end
@interface MPMediaPlaylistCreationMetadata : NSObject
- (instancetype)initWithName:(NSString *)name;
@property (nonatomic, readonly, copy) NSString *name;
@property (null_resettable, nonatomic, copy) NSString *authorDisplayName;
@property (nonatomic, copy) NSString *descriptionText;
@end
@interface MPMediaPlaylist (Charon80Standin)
@property (nonatomic, readonly, nullable) NSArray<MPMediaItem *> *seedItems;
@end

extern NSString *const MPMediaPlaylistPropertySeedItems;

#include "MediaPlayerConstants30.m"
#include "MPMediaPlaylist80.m"
#include "MPMediaPlaylistCreationMetadata93.m"

@implementation MPMediaItem
@end

@implementation MPMediaPlaylist
- (id)valueForProperty:(NSString *)property { (void)property; return nil; }
@end

@interface FakePlaylist : MPMediaPlaylist
{ id _value; }
- (instancetype)initWithCharonValue:(id)value;
@end
@implementation FakePlaylist
- (instancetype)initWithCharonValue:(id)value { self = [super init]; if (self) { _value = value; } return self; }
- (id)valueForProperty:(NSString *)property {
    return [property isEqualToString:MPMediaPlaylistPropertySeedItems] ? _value : nil;
}
@end

static int failures = 0;
static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    MPMediaItem *a = [[MPMediaItem alloc] init], *b = [[MPMediaItem alloc] init];
    FakePlaylist *withItems = [[FakePlaylist alloc] initWithCharonValue:@[a, b]];
    check("seedItems answers the array the release holds under the key",
          [(FakePlaylist *)withItems seedItems].count == 2, "2");
    FakePlaylist *withString = [[FakePlaylist alloc] initWithCharonValue:@"not an array"];
    check("a value of the WRONG type is refused as nil, not forwarded under an NSArray declaration",
          [(FakePlaylist *)withString seedItems] == nil, "nil");
    FakePlaylist *withMixed = [[FakePlaylist alloc] initWithCharonValue:@[a, @"not an item"]];
    check("an array holding one element of the wrong kind is refused WHOLE, not partly",
          [(FakePlaylist *)withMixed seedItems] == nil, "nil");
    FakePlaylist *empty = [[FakePlaylist alloc] initWithCharonValue:@[]];
    check("an empty array is a real answer and is not confused with nil",
          [(FakePlaylist *)empty seedItems] != nil &&
          [(FakePlaylist *)empty seedItems].count == 0, "0 items, not nil");

    MPMediaPlaylistCreationMetadata *meta =
        [[MPMediaPlaylistCreationMetadata alloc] initWithName:@"Road Trip"];
    check("the designated initializer's name reads back",
          [meta.name isEqualToString:@"Road Trip"], "Road Trip");
    meta.descriptionText = @"for the car";
    check("descriptionText is readwrite as the header declares it",
          [meta.descriptionText isEqualToString:@"for the car"], "for the car");
    NSString *author = meta.authorDisplayName;
    check("authorDisplayName is non-nil even when never set: the header's null_resettable default",
          author != nil && author.length > 0, author.UTF8String);
    meta.authorDisplayName = @"Someone Else";
    check("an explicit authorDisplayName wins over the default",
          [meta.authorDisplayName isEqualToString:@"Someone Else"], "Someone Else");
    meta.authorDisplayName = nil;
    check("resetting to nil goes back to the default rather than to nil, which is what null_resettable means",
          meta.authorDisplayName != nil && ![meta.authorDisplayName isEqualToString:@"Someone Else"],
          "the default again");

    if (failures) { printf("playlistvalueholders: %d RED\n", failures); return 1; }
    printf("playlistvalueholders: OK (0 failures)\n");
    return 0;
}
