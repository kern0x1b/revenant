#import <UIKit/UIKit.h>
#import "uikitnames-cases.h"

static NSString *rect_text(CGRect rect)
{
    return [NSString stringWithFormat:@"%.1f %.1f %.1f %.1f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

void uikitnames_run(UIKitNamesRecorder record)
{
    NSDictionary *strings = @{
        @"UITransitionContextFromViewControllerKey": UITransitionContextFromViewControllerKey,
        @"UITransitionContextToViewControllerKey": UITransitionContextToViewControllerKey,
        @"UITransitionContextFromViewKey": UITransitionContextFromViewKey,
        @"UITransitionContextToViewKey": UITransitionContextToViewKey,
        @"UIApplicationUserDidTakeScreenshotNotification": UIApplicationUserDidTakeScreenshotNotification,
        @"UIApplicationBackgroundRefreshStatusDidChangeNotification": UIApplicationBackgroundRefreshStatusDidChangeNotification,
        @"UIActivityTypePostToFlickr": UIActivityTypePostToFlickr,
        @"UIActivityTypePostToVimeo": UIActivityTypePostToVimeo,
        @"UIActivityTypePostToTencentWeibo": UIActivityTypePostToTencentWeibo,
        @"UIActivityTypeAddToReadingList": UIActivityTypeAddToReadingList,
        @"UIActivityTypeOpenInIBooks": UIActivityTypeOpenInIBooks,
        @"UIFontTextStyleCallout": UIFontTextStyleCallout,
        @"UIFontTextStyleTitle1": UIFontTextStyleTitle1,
        @"UIFontTextStyleTitle2": UIFontTextStyleTitle2,
        @"UIFontTextStyleTitle3": UIFontTextStyleTitle3,
        @"UIKeyboardIsLocalUserInfoKey": UIKeyboardIsLocalUserInfoKey,
        @"UIApplicationOpenURLOptionsOpenInPlaceKey": UIApplicationOpenURLOptionsOpenInPlaceKey,
        @"UIApplicationOpenURLOptionsSourceApplicationKey": UIApplicationOpenURLOptionsSourceApplicationKey,
    };
    for (NSString *name in strings)
        record([@"constant." stringByAppendingString:name], strings[name]);
    record(@"constant.fetchInterval", [NSString stringWithFormat:@"%g %d", UIApplicationBackgroundFetchIntervalMinimum, UIApplicationBackgroundFetchIntervalNever == DBL_MAX]);
    record(@"constant.tabBarTrait", [NSString stringWithFormat:@"%llu", (unsigned long long)UIAccessibilityTraitTabBar]);
    record(@"constant.automaticSize", [NSString stringWithFormat:@"%d %d", UICollectionViewFlowLayoutAutomaticSize.width == CGFLOAT_MAX, UICollectionViewFlowLayoutAutomaticSize.height == CGFLOAT_MAX]);
    for (NSString *style in @[UIFontTextStyleCallout, UIFontTextStyleTitle1, UIFontTextStyleTitle2, UIFontTextStyleTitle3])
        record([@"font." stringByAppendingString:style], [NSString stringWithFormat:@"%.0f", [UIFont preferredFontForTextStyle:style].pointSize]);

    UIScreenEdgePanGestureRecognizer *edge = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:nil action:nil];
    record(@"edge.new", [NSString stringWithFormat:@"%@ edges=%lu min=%lu max=%lu", NSStringFromClass([edge superclass]), (unsigned long)edge.edges, (unsigned long)edge.minimumNumberOfTouches, (unsigned long)edge.maximumNumberOfTouches]);
    edge.edges = UIRectEdgeLeft | UIRectEdgeRight;
    record(@"edge.set", [NSString stringWithFormat:@"%lu", (unsigned long)edge.edges]);
    record(@"edge.pan", [NSString stringWithFormat:@"%d %d", [edge isKindOfClass:[UIPanGestureRecognizer class]], [edge isKindOfClass:[UIGestureRecognizer class]]]);

    UIPercentDrivenInteractiveTransition *transition = [[UIPercentDrivenInteractiveTransition alloc] init];
    record(@"transition.new", [NSString stringWithFormat:@"%@ duration=%.1f percent=%.1f speed=%.1f curve=%ld", NSStringFromClass([transition superclass]), transition.duration, transition.percentComplete, transition.completionSpeed, (long)transition.completionCurve]);
    record(@"transition.protocol", [NSString stringWithFormat:@"%d", [transition conformsToProtocol:@protocol(UIViewControllerInteractiveTransitioning)]]);
    transition.completionSpeed = 2;
    transition.completionCurve = UIViewAnimationCurveEaseIn;
    record(@"transition.set", [NSString stringWithFormat:@"%.1f %ld", transition.completionSpeed, (long)transition.completionCurve]);
    [transition updateInteractiveTransition:0.4];
    [transition cancelInteractiveTransition];
    [transition finishInteractiveTransition];
    record(@"transition.update", [NSString stringWithFormat:@"%.1f", transition.percentComplete]);
    [transition updateInteractiveTransition:1.5];
    record(@"transition.over", [NSString stringWithFormat:@"%.1f", transition.percentComplete]);
    [transition updateInteractiveTransition:-1];
    record(@"transition.under", [NSString stringWithFormat:@"%.1f", transition.percentComplete]);

    UIView *loose = [[UIView alloc] initWithFrame:CGRectMake(5, 6, 50, 50)];
    record(@"convert.loose", rect_text(UIAccessibilityConvertFrameToScreenCoordinates(CGRectMake(1, 2, 3, 4), loose)));
}
