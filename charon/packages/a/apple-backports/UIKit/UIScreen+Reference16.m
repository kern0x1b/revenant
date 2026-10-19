#import <UIKit/UIKit.h>

// Never posted: the screens of the release have no reference display mode to change.
NSNotificationName const UIScreenReferenceDisplayModeStatusDidChangeNotification = @"UIScreenReferenceDisplayModeStatusDidChangeNotification";

@implementation UIScreen (CharonReference16)

- (UIScreenReferenceDisplayModeStatus)referenceDisplayModeStatus
{
    return UIScreenReferenceDisplayModeStatusNotSupported;
}

// The screens of the release show nothing brighter than SDR white.
- (CGFloat)currentEDRHeadroom
{
    return 1;
}

- (CGFloat)potentialEDRHeadroom
{
    return 1;
}

@end
