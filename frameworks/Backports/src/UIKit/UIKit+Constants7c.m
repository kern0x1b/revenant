#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSString *const BACKPORT_IMPL(UITransitionContextFromViewControllerKey) = @"UITransitionContextFromViewController";
NSString *const BACKPORT_IMPL(UITransitionContextToViewControllerKey) = @"UITransitionContextToViewController";
NSString *const BACKPORT_IMPL(UIApplicationUserDidTakeScreenshotNotification) = @"UIApplicationUserDidTakeScreenshotNotification";
NSString *const BACKPORT_IMPL(UIApplicationBackgroundRefreshStatusDidChangeNotification) = @"UIApplicationBackgroundRefreshStatusDidChangeNotification";
const NSTimeInterval BACKPORT_IMPL(UIApplicationBackgroundFetchIntervalMinimum) = 0;
const NSTimeInterval BACKPORT_IMPL(UIApplicationBackgroundFetchIntervalNever) = DBL_MAX;
UIActivityType const BACKPORT_IMPL(UIActivityTypePostToFlickr) = @"com.apple.UIKit.activity.PostToFlickr";
UIActivityType const BACKPORT_IMPL(UIActivityTypePostToVimeo) = @"com.apple.UIKit.activity.PostToVimeo";
UIActivityType const BACKPORT_IMPL(UIActivityTypePostToTencentWeibo) = @"com.apple.UIKit.activity.TencentWeibo";
UIActivityType const BACKPORT_IMPL(UIActivityTypeAddToReadingList) = @"com.apple.UIKit.activity.AddToReadingList";

CGRect BACKPORT_IMPL(UIAccessibilityConvertFrameToScreenCoordinates)(CGRect rect, UIView *view)
{
    UIWindow *window = view.window;
    if (!window)
        return rect;
    return [window convertRect:[view convertRect:rect toView:window] toWindow:nil];
}
