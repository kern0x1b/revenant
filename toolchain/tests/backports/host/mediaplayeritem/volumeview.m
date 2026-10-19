#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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

    @autoreleasepool {
        UIImage *transient = [[UIImage alloc] init];
        view.volumeWarningSliderImage = transient;
    }
    check("the association retains, so the image survives the caller dropping its reference",
          view.volumeWarningSliderImage != nil, "still there");

    view.volumeWarningSliderImage = nil;
    check("setting it back to nil clears it", view.volumeWarningSliderImage == nil, "nil");

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
