#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AUComponent.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

// AudioToolbox functions of iOS 14, which the release this port runs on does not export. Each is written from the host's
// answer for the same input (tests/backports/host/audiotoolbox-functions prints the host's answers for these, and
// facts/AVFAudio/AudioToolboxFunctions.md has the figures).
#if TARGET_OS_IPHONE
// The icon the host gives for the component, as AudioComponentGetIcon in AudioToolboxFunctions7.m: a blank image of the host's
// size, 32 by 32 points (measured on the macOS host, for the generic output), and nil for NULL (measured).
static UIImage *CharonBlankComponentIcon(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(32, 32), NO, 1);
    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return icon;
}

// AudioComponentCopyIcon. The host answers the generic output's icon as an image, 32 by 32 points, and nil for NULL. The
// host's image is the component's own artwork, which this port does not carry, so the image is blank.
UIImage *AudioComponentCopyIcon(AudioComponent comp)
{
    if (comp == NULL) {
        return nil;
    }
    return CharonBlankComponentIcon();
}
#endif
