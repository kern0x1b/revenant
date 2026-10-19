// MPMediaPlaylist.seedItems (8.0) and MPMediaPlaylistCreationMetadata (9.3), read through the key
// MediaPlayerConstants30.m defines (facts/MediaPlayer/PlaylistValueHolders.md).
//
// The seedItems half puts values of the RIGHT type and of the WRONG type under the port's accessor,
// because the whole content of that method is refusing a value the header's declaration does not allow.
// Removing its array test does not make this check print RED - it makes the check CRASH, with
// "-[__NSCFConstantString countByEnumeratingWithState:objects:count:]: unrecognized selector", because the
// caller then sends an array message to a string. That crash is the verdict for that mutant and it is the
// strongest form of the proof: the guard is not defensive tidiness, it is what stands between a caller and
// an unrecognised selector.
#import <Foundation/Foundation.h>

@class MPContentItem;
@interface MPMediaItem : NSObject
- (id)valueForProperty:(NSString *)property;
@end
@interface MPMediaPlaylist : NSObject
- (id)valueForProperty:(NSString *)property;
@end
// MPMediaPlaylistCreationMetadata is declared here with the header's own members, because the port's
// object implements it and a translation unit that only implements a class it has not declared gets
// "cannot use 'super' because it is a root class" plus a page of undeclared-ivar errors - measured. The
// 16.4 SDK declares the class, so this is only needed for the stand-in build.
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

// The two stand-in classes need @implementations, not just @interfaces: a category and a property
// implementation both reference _OBJC_CLASS_$_MPMediaPlaylist, and without one the link fails with
// "Undefined symbols for architecture arm64" naming the class - measured, the same class of defect as the
// MPSystemMusicPlayerController one in QueueDescriptors.md. MPMediaItem is given an empty body because the
// check only needs instances of it to put in an array.
@implementation MPMediaItem
@end

// MPMediaPlaylist needs a body for the same reason, and doubly so: FakePlaylist is its SUBCLASS, so
// _OBJC_CLASS_$_MPMediaPlaylist and _OBJC_METACLASS_$_MPMediaPlaylist are both referenced - measured, the
// link error names the metaclass as well as the class. -valueForProperty: is overridden by the subclass
// below, so this body is the base's own and answers nil, which is what the real release's base class
// would do for a key it holds nothing under.
@implementation MPMediaPlaylist
- (id)valueForProperty:(NSString *)property { (void)property; return nil; }
@end

// A playlist whose -valueForProperty: answers whatever the test put under the key. This is the RELEASE'S
// own accessor in the real build (it is one of MPMediaPlaylist's 15 own methods on 6.1.3); the stand-in
// supplies it so the port's convenience can be driven.
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
    // The key's VALUE is not asserted here. A first draft compared the port's constant against the
    // literal @"seedItems", which is the code under test compared with itself and certifies nothing. The
    // value's oracle is tests/backports/host/mediaplayeritem/seedkey.m, which links Apple's own
    // MediaPlayer, includes none of this port's sources, and reads the value from the framework - with the
    // two keys whose values are known NOT to follow the name convention in the same run, so the reader is
    // shown live. What is asserted here is the ACCESSOR's behaviour on the key, which is this file's own
    // code and this file's own subject.

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

    // The 9.3 value holder: name once, descriptionText settable, authorDisplayName null_resettable.
    MPMediaPlaylistCreationMetadata *meta =
        [[MPMediaPlaylistCreationMetadata alloc] initWithName:@"Road Trip"];
    check("the designated initializer's name reads back",
          [meta.name isEqualToString:@"Road Trip"], "Road Trip");
    meta.descriptionText = @"for the car";
    check("descriptionText is readwrite as the header declares it",
          [meta.descriptionText isEqualToString:@"for the car"], "for the car");
    // null_resettable: nil means "not set", and the header says the default is the REQUESTING APP's
    // display name - so the answer is this process's own bundle name, not nil.
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
