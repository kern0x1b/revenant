#import <UIKit/UIKit.h>

NSString *const UITransitionContextFromViewControllerKey = @"UITransitionContextFromViewController";
NSString *const UITransitionContextToViewControllerKey = @"UITransitionContextToViewController";
NSString *const UIApplicationUserDidTakeScreenshotNotification = @"UIApplicationUserDidTakeScreenshotNotification";
NSString *const UIApplicationBackgroundRefreshStatusDidChangeNotification = @"UIApplicationBackgroundRefreshStatusDidChangeNotification";
const NSTimeInterval UIApplicationBackgroundFetchIntervalMinimum = 0;
const NSTimeInterval UIApplicationBackgroundFetchIntervalNever = DBL_MAX;
UIActivityType const UIActivityTypePostToFlickr = @"com.apple.UIKit.activity.PostToFlickr";
UIActivityType const UIActivityTypePostToVimeo = @"com.apple.UIKit.activity.PostToVimeo";
UIActivityType const UIActivityTypePostToTencentWeibo = @"com.apple.UIKit.activity.TencentWeibo";
UIActivityType const UIActivityTypeAddToReadingList = @"com.apple.UIKit.activity.AddToReadingList";

CGRect UIAccessibilityConvertFrameToScreenCoordinates(CGRect rect, UIView *view)
{
    UIWindow *window = view.window;
    if (!window)
        return rect;
    return [window convertRect:[view convertRect:rect toView:window] toWindow:nil];
}
