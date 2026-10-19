//
//  CharonNSExtensionContext+NotificationCenter.m
//  NotificationCenter
//
//  The three widget members NotificationCenter adds to NSExtensionContext, for the context the Foundation backport
//  defines. The contract is the one NotificationCenter documents: a widget that no Today host presents is in compact
//  mode, its height is the compact height, and an expanded size is granted only by a host. No host runs here, so the
//  context answers compact for both modes it can be asked about, and the largest mode it may use is compact too.
//
//  Measured, not documented: the display-mode constants are not in any header this package can read. The SDK's
//  NotificationCenter headers on macOS do not declare them, and the device SDK is not installed. So the values below are
//  the documented ones (NCWidgetDisplayModeCompact is 0 and NCWidgetDisplayModeExpanded is 1, the compact height 110
//  points), named here under Charon's own names so they collide with nothing Apple declares.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, CharonWidgetDisplayMode) {
    CharonWidgetDisplayModeCompact = 0,
    CharonWidgetDisplayModeExpanded = 1,
};

// The documented height of a compact widget, in points.
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

// The width of the screen, by the compact height, for compact and expanded alike: no host grants the expanded size.
- (CGSize)widgetMaximumSizeForDisplayMode:(NSInteger)displayMode
{
    return CGSizeMake([UIScreen mainScreen].bounds.size.width, CharonWidgetCompactHeight);
}

@end
