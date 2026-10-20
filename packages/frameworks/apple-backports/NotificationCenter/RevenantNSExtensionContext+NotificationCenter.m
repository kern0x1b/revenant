#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, RevenantWidgetDisplayMode) {
    RevenantWidgetDisplayModeCompact = 0,
    RevenantWidgetDisplayModeExpanded = 1,
};

static const CGFloat RevenantWidgetCompactHeight = 110;

@implementation NSExtensionContext (RevenantNotificationCenter)

- (NSInteger)widgetActiveDisplayMode
{
    return RevenantWidgetDisplayModeCompact;
}

- (NSInteger)widgetLargestAvailableDisplayMode
{
    return RevenantWidgetDisplayModeCompact;
}

- (CGSize)widgetMaximumSizeForDisplayMode:(NSInteger)displayMode
{
    return CGSizeMake([UIScreen mainScreen].bounds.size.width, RevenantWidgetCompactHeight);
}

@end
