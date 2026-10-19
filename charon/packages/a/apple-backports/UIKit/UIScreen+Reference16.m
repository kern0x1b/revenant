#import <UIKit/UIKit.h>

NSNotificationName const UIScreenReferenceDisplayModeStatusDidChangeNotification = @"UIScreenReferenceDisplayModeStatusDidChangeNotification";

@implementation UIScreen (CharonReference16)

- (UIScreenReferenceDisplayModeStatus)referenceDisplayModeStatus
{
    return UIScreenReferenceDisplayModeStatusNotSupported;
}

- (CGFloat)currentEDRHeadroom
{
    return 1;
}

- (CGFloat)potentialEDRHeadroom
{
    return 1;
}

@end
