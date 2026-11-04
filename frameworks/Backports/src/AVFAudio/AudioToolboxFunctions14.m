#include "../revenant_impl.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#if TARGET_OS_IPHONE
static UIImage *RevenantBlankComponentIcon(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(32, 32), NO, 1);
    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return icon;
}

UIImage *BACKPORT_IMPL(AudioComponentCopyIcon)(AudioComponent comp)
{
    if (comp == NULL) {
        return nil;
    }
    return RevenantBlankComponentIcon();
}
#endif
