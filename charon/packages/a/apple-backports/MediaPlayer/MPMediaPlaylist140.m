// MPMediaPlaylist.cloudGlobalID, the 14.0 member, and nothing else.
//
// MPMediaPlaylist.h at SDK 26.2 is the whole contract, quoted:
//
//   MP_EXTERN NSString * const MPMediaPlaylistPropertyCloudGlobalID MP_API(ios(9.0));  // filterable
//   @property (nonatomic, readonly, nullable) NSString *cloudGlobalID MP_API(ios(14.0));
//
// Note the two releases the header itself names, because the split this file exists for is theirs: the
// KEY is 9.0 and the PROPERTY is 14.0. They are in different objects by that reading alone, and
// MediaPlayerConstants82.m holds the key - which facts/MediaPlayer/MediaPlayerConstants.md:4 records as
// MEASURED at 8.2, one release earlier than the header's own 9.0, and as the reason the constants are two
// objects and not one. This file is the 14.0 half and carries nothing from 9.0.
//
// MEASURED, and it is the measurement that makes this carryable rather than invented:
//   - the KEY VALUE is Apple's and was read, not derived: MediaPlayerConstants82.m carries
//     MPMediaPlaylistPropertyCloudGlobalID = "cloudGlobalID", read from Apple's own framework
//     (facts/MediaPlayer/MediaPlayerConstants.md:8-12), which also records why that had to be read -
//     ten of the thirteen MediaPlayer constants the port carries are dotted `public.*` strings, and one
//     holds the SINGULAR form of its own name. A key spelled from the property's name would have been a
//     guess dressed as a fact. This file names the port's own constant and derives nothing.
//   - the ACCESSOR is the release's own. Read with tools/mach32_methods.py from the armv7 cache of 6.1.3
//     (MediaPlayer image at 0x31fe3000): MPMediaPlaylist has 15 own instance methods and 3 own class
//     methods, -valueForProperty: is among the 15, and all 41 of the image's categories were read WITH
//     THE CLASS EACH ONE EXTENDS, resolved through the category's own class pointer - none extends
//     MPMediaPlaylist. So nothing here clobbers the release's accessor and nothing in the release
//     clobbers this. -aSelectorNoFrameworkHas is absent as the control.
//   - -cloudGlobalID is declared by none of the image's 236 classes and the release's whole-cache selector
//     list has no line for it, so it is the port's to carry.
//
// THE ANSWER ON 6.1.3, which is the honest part and not a limitation to apologise for. A global ID is the
// identifier a playlist has in the user's iCloud account. iOS 6.1.3 has no iCloud music library at all -
// MPMediaPlaylist's own 15 methods are initWithPersistentID: (a LOCAL persistent ID), -items, -count,
// -persistentID, -valueForProperty:, -playlistAttributes, -mediaTypes, -representativeItem,
// -existsInLibrary, -isEqual:, -encodeWithCoder:, -initWithCoder: and the artwork loader, and the image's
// cloud classes (MPCloudController, MPCloudDownloadButton, MPCloudAssetDownloadController) are all
// download machinery for the app's own cache. So the release answers nil under that key and nil is what
// this answers. It is not a stub and not a placeholder: it is Apple's own key read through Apple's own
// accessor, and on a release that has an iCloud account to name it answers the ID. That is the difference
// this port exists to preserve - the ANSWER, not the presence of the symbol - and a cloudGlobalID that
// answered some invented string on a device with no cloud would be the failure mode, not the success one.
//
// One object per release, per band()'s own rule: this file holds the 14.0 member, and MPMediaPlaylist's
// 9.3 members and its 8.0 seedItems are files of their own.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

// A CATEGORY on a class the release owns, not an @implementation of it: the release's MPMediaPlaylist
// carries -valueForProperty: and the other 14 own methods, and this file adds one selector to it. Written
// as a bare `@implementation MPMediaPlaylist` it would claim the whole class.
#if defined(CHARON_MEDIAPLAYER_STANDIN)
@interface MPMediaPlaylist : NSObject
- (id)valueForProperty:(NSString *)property;
@end
// The SDK's own declaration of the member is not available to the stand-in build, so the contract is
// restated here for it - read from MPMediaPlaylist.h above, not invented for the check to pass.
@interface MPMediaPlaylist (Charon140)
@property (nonatomic, readonly, nullable) NSString *cloudGlobalID;
@end
#endif

// The port's own copy of Apple's key, declared as the plain extern MediaPlayerConstants82.m uses for the
// same name. This file imports the framework, so in the non-stand-in build the SDK's own declaration is
// what this refers to; the extern is what lets the stand-in build reach it, and it names the same symbol,
// so there is one value per name and not two.
extern NSString *const MPMediaPlaylistPropertyCloudGlobalID;

@implementation MPMediaPlaylist (Charon140)

// The header's readonly accessor, written out rather than left to the synthesiser, so what a caller reads
// is the port's own code. -valueForProperty: is typed `id` and the property is typed
// `nullable NSString *`: a value that is not an NSString is answered nil rather than forwarded, because
// forwarding it would hand a caller an object under a declaration that says NSString and the crash would
// arrive at the caller's first message to it.
- (nullable NSString *)cloudGlobalID {
    id value = [self valueForProperty:MPMediaPlaylistPropertyCloudGlobalID];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

@end