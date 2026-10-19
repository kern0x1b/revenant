// MPMediaPickerController.showsItemsWithProtectedAssets, the 9.2 member, and nothing else.
//
// MPMediaPickerController.h at SDK 26.2 is the whole contract, quoted, including the default the header
// itself states:
//
//   @property (nonatomic) BOOL showsItemsWithProtectedAssets MP_API(ios(9.2)); // default is YES
//
// readwrite. So this is a stored flag whose unset value is YES, and the header is where that comes from.
//
// MEASURED, read with tools/mach32_methods.py from the armv7 cache of 6.1.3 (MediaPlayer image at
// 0x31fe3000):
//   - MPMediaPickerController has 19 own instance methods and 1 own class method, and neither
//     `showsItemsWithProtectedAssets` nor `setShowsItemsWithProtectedAssets:` is among them.
//   - all 41 of the image's categories were read WITH THE CLASS EACH ONE EXTENDS and none extends
//     MPMediaPickerController, so nothing here clobbers a release accessor and nothing in the release
//     clobbers this one. -aSelectorNoFrameworkHas is absent as the control.
//   - the selector is on NO line of the release's whole-cache selector list (113981 distinct names, a list
//     of names and not a count per class), so no class anywhere in 6.1.3 declares it. That is absence from
//     the release, not merely from this framework, and it is the one of these four measurements where the
//     per-cache list IS the right rung.
//
// WHAT IT ANSWERS ON 6.1.3, stated rather than glossed. FairPlay protected assets arrived with iTunes
// Match, which is iOS 7 and later; 6.1.3 has no protected asset for the flag to be about. So the flag
// round-trips what the app set - YES unless the app said NO - and no item is ever filtered, because there
// is none to filter. That is Apple's own answer on this release rather than a stub: the getter returns the
// stored value, and on a release where the picker filters, the same getter returns the stored value and the
// picker filters.
//
// STORAGE. A category cannot add an ivar and this is a CATEGORY on a class the release owns, so the value
// is an associated object - public API, and what this tree already does for the same problem
// (WebKit/WKWebpagePreferences13.m:39-42, SensorKit/SRSensorReader.m:120-135). A distinct static address
// per stored property, as WebKit does, so no selector this port does not define is registered anywhere.
//
// One object per release, per band()'s own rule: this file holds the 9.2 member and not MPMediaPickerController's
// 6.0 showsCloudItems, which the release carries.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif
#import <objc/runtime.h>

#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The SDK's own declaration is not available to the stand-in build, so the contract is restated for it -
// read from MPMediaPickerController.h above, not invented for the check to pass.
@interface MPMediaPickerController : NSObject
@property (nonatomic) BOOL showsCloudItems;
@end
@interface MPMediaPickerController (Charon92)
@property (nonatomic) BOOL showsItemsWithProtectedAssets;
@end
#endif

static const void *charon_mediaplayer_protected_assets_key = &charon_mediaplayer_protected_assets_key;

// A CATEGORY on a class the release owns, not an @implementation of it.
@implementation MPMediaPickerController (Charon92)

- (BOOL)showsItemsWithProtectedAssets {
    // YES is the header's own stated default, so an object nobody has set the flag on answers YES and a
    // caller that only ever reads it never sees a value the release would not.
    NSNumber *held = objc_getAssociatedObject(self, charon_mediaplayer_protected_assets_key);
    return held ? [held boolValue] : YES;
}

- (void)setShowsItemsWithProtectedAssets:(BOOL)showsItemsWithProtectedAssets {
    objc_setAssociatedObject(self, charon_mediaplayer_protected_assets_key,
                             [NSNumber numberWithBool:showsItemsWithProtectedAssets],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end