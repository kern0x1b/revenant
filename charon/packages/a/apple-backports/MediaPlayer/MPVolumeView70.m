// MPVolumeView.volumeWarningSliderImage, the 7.0 property, as a stored image the release's own volume
// slider can be told to draw.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 cache of 6.1.3 (commands in
// facts/MediaPlayer/LanguageOptions.md; controls as that page records). MPVolumeView is PRESENT with 54
// own instance methods and 0 own class methods, and:
//
//   -volumeWarningSliderImage        absent   of the 54
//   -setVolumeWarningSliderImage:    absent   of the 54
//   -volumeThumbImageForState:       PRESENT
//   -setVolumeThumbImage:forState:   PRESENT
//   -minimumVolumeSliderImageForState:   PRESENT
//   -setMinimumVolumeSliderImage:forState: PRESENT
//   -showsVolumeSlider               PRESENT
//   -setShowsVolumeSlider:           PRESENT
//   -volumeSlider                    PRESENT
//
// and across all 11378 classes of the whole 6.1.3 cache exactly ZERO declare -volumeWarningSliderImage, so
// no category in any framework supplies it either.
//
// WHY THIS ROW IS DIFFERENT FROM THE TWO MPVolumeView ROWS BESIDE IT, and that is worth being exact about,
// because facts/MediaPlayer/AbsentRows.md keeps those two absent and a reader will ask why this one is not.
// Those two are `wirelessRoutesAvailable` and `wirelessRouteActive`, and their answer needs a STATE that
// does not exist on this release: the route state behind the AirPlay UI is MPAudioDeviceController's
// private tables and no public API on 6.1.3 reads it. THIS property needs no such state. It is
// `@property (nonatomic, strong, nullable) UIImage *volumeWarningSliderImage MP_API(ios(7.0));` - a
// readwrite image the CALLER supplies. There is nothing to discover; there is something to store, and
// what to store is the caller's own UIImage. That is the whole difference between a property whose answer
// the device must know and one whose answer the caller brings.
//
// IT IS NOT INERT, and the difference is the check. A stored image nothing draws would be an accessor pair
// that loads and does nothing - `inert`, or a claim of more than is true. It is not that: the release's
// own -setVolumeThumbImage:forState: and -volumeThumbImageForState: are among its 54, and they are how a
// caller already customises the image on this release's volume slider. So the image a caller sets here is
// an image the release's slider machinery is already equipped to hold, and the row's effect says exactly
// what it is: the value is stored and the release's own thumb accessors are how it would be drawn. What
// this file does NOT do is claim the release draws it automatically - nothing in the release's 54 methods
// reads a property of that name, because the property is the 7.0 one and the release predates it.
//
// A CATEGORY on a class the release owns, not an @implementation of it: the release's MPVolumeView is the
// one that carries those 54 methods, and this adds one selector pair to it. Written as a bare
// @implementation MPVolumeView it would claim the whole class.
//
// The image is held STRONGLY because the property is `strong`, and ARC then keeps it alive for exactly as
// long as the view holds it - the caller is not expected to, and must not have to, retain it separately.
// It is a strong reference and not a copy: a UIImage is immutable by contract, and copying one would
// produce a second object that the release's own drawing code would not recognise as the one it was given.
//
// One object per release: this file holds the 7.0 property. The two wireless-route rows stay absent, in
// this file's own file scope of concern and in AbsentRows.md, and MediaPlayerConstants70.m holds the 7.0
// notification constants.

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

// The image is held as an ASSOCIATED OBJECT, not an ivar, and that is forced rather than chosen: a
// category cannot declare an instance variable, and clang says so exactly - "@synthesize not allowed in a
// category's implementation" followed by two undeclared-identifier errors on the ivar, measured. The
// alternative would be a subclass, which would claim a class the release already owns.
//
// This is the tree's own idiom for the same shape, not a new mechanism: UIKit/CADisplayLink+FrameRate.m
// stores its two values the same way, with a `static const char` key and OBJC_ASSOCIATION_RETAIN_NONATOMIC.
// A distinct static key per associated object is what keeps two ports' categories on one class from
// colliding, and a file-scope `static const char` is a unique address for the lifetime of the image.
static const char CharonVolumeWarningSliderImageKey;

// A CATEGORY, because the release owns the class. None of the image's categories extends MPVolumeView -
// facts/MediaPlayer/AbsentRows.md records that its 41 categories land on UIImage, NSObject, UIView and
// others, and resolves each one through the category's own class pointer rather than by its name - so
// nothing here clobbers a release accessor and nothing in the release clobbers this one.
@implementation MPVolumeView (Charon70)

// The getter is nullable because the header says so, and nil is the honest answer for a property nobody
// set: a view with no warning image is the normal state, not an error - so the first read of a fresh view
// returns nil and the check asserts exactly that.
- (nullable UIImage *)volumeWarningSliderImage {
    return objc_getAssociatedObject(self, &CharonVolumeWarningSliderImageKey);
}

// OBJC_ASSOCIATION_RETAIN_NONATOMIC, which is `strong` for the property the header declares
// (`@property (nonatomic, strong, nullable) UIImage *`) and not `copy`: a UIImage is immutable by contract,
// and copying one would produce a second object the release's own drawing code would not recognise as the
// one the caller supplied. The association retains it for exactly as long as the view holds it, so the
// caller neither has to retain it separately nor has to keep it alive itself.
- (void)setVolumeWarningSliderImage:(nullable UIImage *)volumeWarningSliderImage {
    objc_setAssociatedObject(self, &CharonVolumeWarningSliderImageKey, volumeWarningSliderImage,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
