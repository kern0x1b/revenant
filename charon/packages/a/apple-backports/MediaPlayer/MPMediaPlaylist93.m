// MPMediaPlaylist's 9.3 members, the two properties its header declares at MP_API(ios(9.3)), and nothing
// else.
//
// MPMediaPlaylist.h at SDK 26.2 is the whole contract, quoted:
//
//   MP_EXTERN NSString * const MPMediaPlaylistPropertyDescriptionText MP_API(ios(9.3));
//   @property (nonatomic, readonly, nullable) NSString *descriptionText MP_API(ios(9.3));
//   MP_EXTERN NSString * const MPMediaPlaylistPropertyAuthorDisplayName MP_API(ios(9.3));
//   @property (nonatomic, readonly, nullable) NSString *authorDisplayName MP_API(ios(9.3));
//
// Each property is a named property key over -valueForProperty:, which is what the header says they are:
// every one of these is declared as a `MPMediaPlaylistProperty*` constant beside a property of the same
// name, and -valueForProperty: is the one accessor that takes such a key.
//
// MEASURED, and it is the measurement that makes these two carryable rather than invented:
//   - the KEY VALUES are Apple's, not this file's. MediaPlayerConstants93.m carries
//     MPMediaPlaylistPropertyAuthorDisplayName and MPMediaPlaylistPropertyDescriptionText, and their
//     values were read from Apple's own framework (facts/MediaPlayer/MediaPlayerConstants.md:8-12) - they
//     are "externalVendorDisplayName" and "descriptionInfo", and NEITHER is the name of the constant or
//     the name of the property. A key derived from the property's name would have been wrong twice, which
//     is why this file names the port's own constants and derives nothing.
//   - the ACCESSOR the properties are conveniences over is the release's own. Read with
//     tools/mach32_methods.py from the armv7 cache of 6.1.3 (MediaPlayer image at 0x31fe3000):
//     MPMediaPlaylist has 15 own instance methods and 3 own class methods and -valueForProperty: is among
//     the 15. All 41 of the image's categories were read WITH THE CLASS EACH ONE EXTENDS, resolved
//     through the category's own class pointer, and none of them extends MPMediaPlaylist - they land on
//     UIImage, NSObject, NSIndexSet, UIApplication, UIWindow, UIView, AVMediaSelectionOption,
//     AVPlayerItem, NSArray, NSMutableArray, NSBundle, NSOperation, NSOperationQueue, ML3Entity,
//     ML3Collection, ML3Album, ML3Artist, ML3AlbumArtist, ML3Composer, ML3Genre, ML3Container, ML3Track,
//     NSString, NSNumber, UIDevice, AVAsset, UIViewController and SSLookupResponse. So nothing here can
//     clobber the release's accessor and nothing in the release clobbers these.
//     -aSelectorNoFrameworkHas is absent as the control.
//   - neither -authorDisplayName nor -descriptionText is declared by ANY of the image's 236 classes, and
//     the release's whole-cache selector list has no line for either. So both are the port's to carry.
//
// THE TYPE, which is where a one-line forward would have been wrong. -valueForProperty: is typed `id` and
// the two properties are typed `nullable NSString *`. The release knows what it put under those keys; the
// port does not, because the release's own key-value store is not readable from outside. A value that is
// not an NSString is therefore answered nil rather than forwarded: forwarding it would hand a caller an
// object under a declaration that says NSString, and the first message the caller sends would be
// -length or -substringToIndex: on it, which is a crash the caller cannot see coming. nil is the header's
// own nullable, and a playlist that has no author is the case the nullability is there for.
//
// One object per release, per band()'s own rule: this file holds the 9.3 members and not MPMediaPlaylist's
// 8.0 seedItems or its 14.0 cloudGlobalID, which are files of their own.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

// A CATEGORY on a class the release owns, not an @implementation of it: the release's MPMediaPlaylist
// is the one that carries -valueForProperty: and the other 14 own methods, and this file adds two
// selectors to it. Written as a bare `@implementation MPMediaPlaylist` it would claim the whole class.
#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The stand-in declares MPMediaItem and no MPMediaPlaylist. The release's shape is
// MPMediaPlaylist : MPMediaEntity (its own 15 include initWithPersistentID:, -items, -count,
// -persistentID, -valueForProperty: and -playlistAttributes, and none of the image's 41 categories
// extends MPMediaPlaylist), so the stand-in's playlist is a plain NSObject with the one accessor these
// two properties are conveniences over.
@interface MPMediaPlaylist : NSObject
- (id)valueForProperty:(NSString *)property;
@end
// The SDK's own declarations of the two members are not available to the stand-in build, so the contract
// is restated here for it - read from MPMediaPlaylist.h above, not invented for the check to pass.
@interface MPMediaPlaylist (Charon93)
@property (nonatomic, readonly, nullable) NSString *authorDisplayName;
@property (nonatomic, readonly, nullable) NSString *descriptionText;
@end
#endif

// The port's own copies of Apple's keys, declared here as the plain extern MediaPlayerConstants93.m uses
// for the same two names. This file imports the framework, so in the non-stand-in build the SDK's own
// declaration is what these refer to; the extern is what lets the stand-in build reach them, and it names
// the same symbols, so there is one value per name and not two.
extern NSString *const MPMediaPlaylistPropertyAuthorDisplayName;
extern NSString *const MPMediaPlaylistPropertyDescriptionText;

@implementation MPMediaPlaylist (Charon93)

// The header's readonly accessors, written out rather than left to the synthesiser, so what a caller
// reads is the port's own code. `id` is what the release answers and NSString is what the header declares:
// the cast is refused rather than asserted, and nil is what a playlist with no value under the key says.
- (nullable NSString *)authorDisplayName {
    id value = [self valueForProperty:MPMediaPlaylistPropertyAuthorDisplayName];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

- (nullable NSString *)descriptionText {
    id value = [self valueForProperty:MPMediaPlaylistPropertyDescriptionText];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

@end