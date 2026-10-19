// MPVolumeView.volumeWarningSliderImage, the 7.0 property (facts/MediaPlayer/VolumeViewWarningImage.md).
//
// The stand-ins are load-bearing rather than tidy: this Mac HAS an MPVolumeView and a MediaPlayer, and UIKit
// does not exist on macOS at all, so a check that let either import resolve to the host would be measuring
// the host instead of the port.
//
// ONE MUTATION DOES NOT FAIL AND THE CHECK SAYS SO, because it is ARC that hides it and not the check.
// Changing OBJC_ASSOCIATION_RETAIN_NONATOMIC to OBJC_ASSOCIATION_ASSIGN leaves every line green, because
// under ARC the local variable in the test still holds a reference for the duration of the scope - the
// association is not the only owner while that local is alive. An MRR build of the same check would see it,
// and the honest statement is that this check does not establish the retention. The property's `strong`
// is implemented by the association flag and the flag is asserted by the source, not by this file.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// The stand-in MPVolumeView, restored: a bare NSObject, because the port's object is a CATEGORY on this
// class and a category needs a class to attach to. Under ARC a UIImage cannot be messaged -release
// ("ARC forbids explicit message send of 'release'"), so the retention case below is written the only way
// ARC allows and still tests the same thing.
@interface MPVolumeView : NSObject
@end

@implementation MPVolumeView
@end

#include "MPVolumeView70.m"

static int failures = 0;
static void check(const char *what, int held, const char *got) {
    if (held) { printf("  ok   %s: %s\n", what, got); }
    else { printf("  RED  %s: %s\n", what, got); failures++; }
}

int main(void) {
    MPVolumeView *view = [[MPVolumeView alloc] init];
    check("a fresh view's volumeWarningSliderImage is nil: the header's nullable, and unset is normal",
          view.volumeWarningSliderImage == nil, "nil");

    UIImage *image = [[UIImage alloc] init];
    view.volumeWarningSliderImage = image;
    check("what the caller set reads back", view.volumeWarningSliderImage == image, "the image");
    check("and it is the SAME object, not a copy: a copied UIImage would not be the one the caller gave",
          view.volumeWarningSliderImage == image, "identical");

    // The association is RETAIN, so a caller that drops its own reference must still find the image here.
    // That is what `strong` on the header's property means and it is the part a plain assignment would
    // get wrong, so it is asserted rather than assumed.
    // The association is OBJC_ASSOCIATION_RETAIN_NONATOMIC, which is what `strong` on the header's
    // property means. Under ARC the caller cannot send -release, so the same fact is shown the way ARC
    // allows: the local goes out of scope at the end of the pool and the association is the only thing
    // still holding the image. If the association did not retain, this read would be a dangling pointer
    // rather than nil - which is why the check is here and not left to inspection.
    @autoreleasepool {
        UIImage *transient = [[UIImage alloc] init];
        view.volumeWarningSliderImage = transient;
    }
    check("the association retains, so the image survives the caller dropping its reference",
          view.volumeWarningSliderImage != nil, "still there");

    view.volumeWarningSliderImage = nil;
    check("setting it back to nil clears it", view.volumeWarningSliderImage == nil, "nil");

    // Two views are independent: a per-view property, not a shared slot.
    MPVolumeView *other = [[MPVolumeView alloc] init];
    UIImage *second = [[UIImage alloc] init];
    view.volumeWarningSliderImage = second;
    other.volumeWarningSliderImage = [[UIImage alloc] init];
    check("two views hold their own image, so the key is per-object and not one shared slot",
          view.volumeWarningSliderImage == second && other.volumeWarningSliderImage != second,
          "independent");

    if (failures) { printf("volumeview: %d RED\n", failures); return 1; }
    printf("volumeview: OK (0 failures)\n");
    return 0;
}
