#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, CharonWidgetDisplayMode) {
    CharonWidgetDisplayModeCompact = 0,
    CharonWidgetDisplayModeExpanded = 1,
};

static const CGFloat CharonWidgetCompactHeight = 110;

@implementation NSExtensionContext (CharonNotificationCenter)

- (NSInteger)widgetActiveDisplayMode
{
    return CharonWidgetDisplayModeCompact;
}

- (NSInteger)widgetLargestAvailableDisplayMode
{
    return CharonWidgetDisplayModeCompact;
}

- (CGSize)widgetMaximumSizeForDisplayMode:(NSInteger)displayMode
{
    return CGSizeMake([UIScreen mainScreen].bounds.size.width, CharonWidgetCompactHeight);
}

@end
