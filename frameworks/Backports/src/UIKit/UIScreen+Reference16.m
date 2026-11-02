#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSNotificationName const BACKPORT_IMPL(UIScreenReferenceDisplayModeStatusDidChangeNotification) = @"UIScreenReferenceDisplayModeStatusDidChangeNotification";

@implementation UIScreen (RevenantReference16)

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
