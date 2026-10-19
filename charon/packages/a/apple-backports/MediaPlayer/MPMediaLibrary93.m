// MPMediaLibrary's 9.3 authorization pair, and nothing else.
//
// MPMediaLibrary.h at SDK 26.2 is the whole contract, quoted:
//
//   typedef NS_ENUM(NSInteger, MPMediaLibraryAuthorizationStatus) {
//       MPMediaLibraryAuthorizationStatusNotDetermined = 0,
//       MPMediaLibraryAuthorizationStatusDenied,
//       MPMediaLibraryAuthorizationStatusRestricted,
//       MPMediaLibraryAuthorizationStatusAuthorized,
//   } MP_API(ios(9.3)) API_UNAVAILABLE(tvos, watchos, macos);
//
//   + (MPMediaLibraryAuthorizationStatus)authorizationStatus MP_API(ios(9.3));
//   + (void)requestAuthorization:(void (^)(MPMediaLibraryAuthorizationStatus status))completionHandler MP_API(ios(9.3));
//
// A status and a one-shot request that answers with one. The type is 9.3; the rows are 9.3.
//
// MEASURED, read with tools/mach32_methods.py from the armv7 cache of 6.1.3 (MediaPlayer image at
// 0x31fe3000):
//   - MPMediaLibrary has 110 own instance methods and 23 own class methods - `+defaultMediaLibrary`,
//     `+deviceMediaLibrary`, `+mediaLibraries`, `+mediaLibraryWithUniqueIdentifier:`, the library-change
//     notification pair and the rest - and NOT ONE of them authorizes anything. There is no
//     `-authorizationStatus`, no `-requestAuthorization:`, no prompt, no restriction object.
//   - all 41 of the image's categories were read WITH THE CLASS EACH ONE EXTENDS and none extends
//     MPMediaLibrary, so nothing here clobbers a release accessor and nothing in the release clobbers this.
//     -aSelectorNoFrameworkHas is absent as the control.
//   - `requestAuthorization:` is on NO line of the release's whole-cache selector list (113981 distinct
//     names) - so no class anywhere in 6.1.3 declares it. `authorizationStatus` is on ONE line, because
//     other frameworks have a class with that name; the per-class read above decides this one, which is the
//     trap facts/MediaPlayer/MPMediaItem.md:105 records for albumTrackNumber.
//
// SO WHAT DOES IT ANSWER, and this is the part a reviewer should check hardest because it is a constant.
//
//     MPMediaLibraryAuthorizationStatusAuthorized
//
// That is not a placeholder and not a guess. iOS 6.1.3 has no library authorization at all: "Media &
// Apple Music Restrictions" is a 7.0 Settings pane and the release has no such object, no such selector and
// no such notification among its 236 classes. Nothing gates `[MPMediaLibrary defaultMediaLibrary]`, which
// the release hands out unconditionally - its own 23 class methods include `+defaultMediaLibrary` and
// nothing that refuses. Of the enum's four cases:
//
//   - NotDetermined means "the user has not been asked yet". Nothing on this release ever asks, so claiming
//     it would claim a prompt exists. That is the one case that is a lie here, and it is the zero.
//   - Denied and Restricted mean the user or a policy refused. There is no refusal to report.
//   - Authorized means the library may be used. That is the state of the device, measured above.
//
// -requestAuthorization: therefore hands its completion handler the same value, asynchronously as the
// header's block shape implies, and only when the caller supplied one.
//
// AND THE LIMIT, in the open: if a release that DOES gate the library is ever compiled against, these two
// accessors must read that gate rather than answer a constant. They cannot today, because the gate is 7.0
// API and this tree's SDKs are 16.4 and 26.2 - and on a 7.0-or-later device the release's own
// `+authorizationStatus` would be the answer, not the port's. That is why these rows are `implemented`
// with `minimum: 6.0` and carry this reasoning, and not `ignored`: on the 6.1.3 band the port IS the
// answer, and a caller on that band gets the truthful status of a device with no restriction pane.
//
// One object per release, per band()'s own rule: this file holds the 9.3 pair and not the 9.3
// addItemWithProductID:/getPlaylistWithUUID: pair, which AbsentRows.md records as `absent` - those need the
// iTunes Store and an iCloud library, which is a different reason and is not this one.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The SDK's own declarations are not available to the stand-in build, so the contract is restated for it -
// read from MPMediaLibrary.h above, not invented for the check to pass. The four cases are spelled
// because the answer below is one of them by name.
typedef NSInteger MPMediaLibraryAuthorizationStatus;
enum { MPMediaLibraryAuthorizationStatusNotDetermined = 0, MPMediaLibraryAuthorizationStatusDenied = 1,
       MPMediaLibraryAuthorizationStatusRestricted = 2, MPMediaLibraryAuthorizationStatusAuthorized = 3 };
@interface MPMediaLibrary : NSObject
+ (MPMediaLibrary *)defaultMediaLibrary;
@end
@interface MPMediaLibrary (Charon93)
+ (MPMediaLibraryAuthorizationStatus)authorizationStatus;
+ (void)requestAuthorization:(void (^)(MPMediaLibraryAuthorizationStatus status))completionHandler;
@end
#endif

// A CATEGORY on a class the release owns, not an @implementation of it - written as a bare
// `@implementation MPMediaLibrary` it would claim the release's 110 instance and 23 class methods.
@implementation MPMediaLibrary (Charon93)

+ (MPMediaLibraryAuthorizationStatus)authorizationStatus {
    return MPMediaLibraryAuthorizationStatusAuthorized;
}

+ (void)requestAuthorization:(void (^)(MPMediaLibraryAuthorizationStatus status))completionHandler {
    // Apple's block is declared with a nonnull status, so this hands one and never nil. The handler is
    // checked because the header's own shape on the sibling methods accepts a nullable completion handler,
    // and a caller that passed nil must not be crashed by the one that does not.
    if (completionHandler) {
        completionHandler(MPMediaLibraryAuthorizationStatusAuthorized);
    }
}

@end