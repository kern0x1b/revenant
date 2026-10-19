// MPMediaPlaylist.seedItems, the 8.0 member, as a convenience over the release's own -valueForProperty:.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 cache of 6.1.3 (commands in
// facts/MediaPlayer/LanguageOptions.md; controls as that page records). MPMediaPlaylist is PRESENT with 15
// own instance methods, and they are:
//
//   -count  -encodeWithCoder:  -existsInLibrary  -hash  -initWithCoder:  -initWithPersistentID:
//   -isEqual:  -items  -loadGeniusMixArtworkWithTileLength:completionBlock:  -mediaTypes  -name
//   -persistentID  -playlistAttributes  -representativeItem  -valueForProperty:
//
// -seedItems and -setSeedItems: are in none of them, and across all 11378 classes of the whole 6.1.3 cache
// exactly ZERO declare -seedItems, so there is no category in any framework supplying it either.
//
// WHAT MAKES IT CARRYABLE is -valueForProperty:, which IS one of the 15: the header declares seedItems as
// `@property (nonatomic, readonly, nullable) NSArray<MPMediaItem *> *seedItems MP_API(ios(8.0));` and the
// comment above it says what it is: for a playlist with the Genius attribute, the seedItems are the
// MPMediaItems that were used to generate the playlist - beside a named key,
// MPMediaPlaylistPropertySeedItems. That is the same shape as the two 9.3 keys MPMediaPlaylist93.m carries:
// a named property key over -valueForProperty:, which is the one accessor that takes such a key.
//
// THE KEY IS AVAILABLE AT 6.1.3, which is the part that has to be checked rather than assumed. The port's
// facts page for the constants records that 6.1.3 exports NONE of MediaPlayer's 36 constants, so a key
// this port declares is one the port carries itself - and this one is different from the 9.3 pair in
// exactly one way that matters: MPMediaPlaylistPropertySeedItems is declared in MPMediaPlaylist.h with NO
// MP_API annotation at all, while the two 9.3 keys carry MP_API(ios(9.3)). An unannotated extern is
// unversioned, so the name belongs to no later release than the header that declares it and the port's own
// copy does not shadow a 6.1.3 symbol that exists. The VALUE is not spelled from the property's name:
// facts/MediaPlayer/MediaPlayerConstants.md:8-12 records that the 9.3 keys' values are "externalVendor-
// DisplayName" and "descriptionInfo", neither of which is the name of the constant or of the property, so
// a value derived from a naming convention would have been wrong there and is not attempted here. The
// key this file uses is the port's own extern, named for the same symbol, so there is one value per name.
//
// THE TYPE IS THE THING TO GET RIGHT. -valueForProperty: returns `id`; the header declares the property
// `nullable NSArray<MPMediaItem *> *`. A value that is not an array of items is therefore answered nil
// rather than forwarded: handing a caller an object under a declaration that says NSArray<MPMediaItem *>*
// would put the first -count or -objectAtIndexedSubscript: on it inside the caller, which is a crash the
// caller cannot see coming. nil is the header's own nullable, and a playlist that is not a Genius mix has
// no seed items, which is the case the nullability is there for.
//
// One object per release, per band()'s own rule: this file holds the 8.0 member. MPMediaPlaylist93.m holds
// the two 9.3 keys and MPMediaPlaylist140.m the 14.0 one, and release-split reads band points only, so a
// file holding all three would pass that check and still be one object for three releases.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The stand-in declares MPMediaItem and no MPMediaPlaylist, so the playlist is a plain NSObject carrying the
// one accessor this property is a convenience over - the release's own shape, MPMediaPlaylist : MPMediaEntity.
@interface MPMediaPlaylist : NSObject
- (id)valueForProperty:(NSString *)property;
@end
// Restated for the stand-in build, read from MPMediaPlaylist.h above and not invented for the check to pass.
@interface MPMediaPlaylist (Charon80)
@property (nonatomic, readonly, nullable) NSArray<MPMediaItem *> *seedItems;
@end
#endif

// The port's own copy of Apple's key, declared as the plain extern MediaPlayerConstants* files use for the
// same names. This file imports the framework, so in the non-stand-in build the SDK's own declaration is
// what this refers to; the extern is what lets the stand-in build reach it, and it names the same symbol,
// so there is one value per name and not two.
extern NSString *const MPMediaPlaylistPropertySeedItems;

// A CATEGORY on a class the release owns, not an @implementation of it: the release's MPMediaPlaylist is
// the one that carries -valueForProperty: and the other 14 own methods, and this adds one selector to it.
// Written as a bare @implementation MPMediaPlaylist it would claim the whole class.
@implementation MPMediaPlaylist (Charon80)

// The header's readonly accessor, written out rather than left to the synthesiser, so what a caller reads
// is the port's own code. `id` is what the release answers and NSArray<MPMediaItem *> is what the header
// declares: the cast is REFUSED rather than asserted, which is the whole content of this method.
- (nullable NSArray<MPMediaItem *> *)seedItems {
    id value = [self valueForProperty:MPMediaPlaylistPropertySeedItems];
    if (![value isKindOfClass:[NSArray class]]) {
        return nil;
    }
    for (id element in (NSArray *)value) {
        if (![element isKindOfClass:[MPMediaItem class]]) {
            // One element of the wrong kind makes the whole answer nil, rather than an array that is
            // declared to hold items and does not. A caller looping it would otherwise send a media-item
            // message to whatever is actually in there.
            return nil;
        }
    }
    return (NSArray<MPMediaItem *> *)value;
}

@end
