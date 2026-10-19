#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char CharonDirectionalMarginsKey;
static char CharonProjectedMarginsKey;

static BOOL charon_view_reverses_layout_direction(UIView *view)
{
    if ([view respondsToSelector:@selector(semanticContentAttribute)]) {
        UISemanticContentAttribute attribute = view.semanticContentAttribute;
        if (attribute == UISemanticContentAttributeForceRightToLeft)
            return YES;
        if (attribute == UISemanticContentAttributeForceLeftToRight)
            return NO;
    }
    return [UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
}

static UIEdgeInsets charon_margins_from_directional(NSDirectionalEdgeInsets insets, BOOL reversed)
{
    return reversed ? UIEdgeInsetsMake(insets.top, insets.trailing, insets.bottom, insets.leading)
                    : UIEdgeInsetsMake(insets.top, insets.leading, insets.bottom, insets.trailing);
}

static NSDirectionalEdgeInsets charon_directional_from_margins(UIEdgeInsets insets, BOOL reversed)
{
    return reversed ? NSDirectionalEdgeInsetsMake(insets.top, insets.right, insets.bottom, insets.left)
                    : NSDirectionalEdgeInsetsMake(insets.top, insets.left, insets.bottom, insets.right);
}

@implementation UIView (CharonDirectionalLayoutMargins)

- (NSDirectionalEdgeInsets)directionalLayoutMargins
{
    NSValue *directional = objc_getAssociatedObject(self, &CharonDirectionalMarginsKey);
    NSValue *projected = objc_getAssociatedObject(self, &CharonProjectedMarginsKey);
    UIEdgeInsets margins = self.layoutMargins;
    if (directional && projected && UIEdgeInsetsEqualToEdgeInsets(projected.UIEdgeInsetsValue, margins)) {
        NSDirectionalEdgeInsets stored = NSDirectionalEdgeInsetsZero;
        [directional getValue:&stored];
        return stored;
    }
    return charon_directional_from_margins(margins, charon_view_reverses_layout_direction(self));
}

- (void)setDirectionalLayoutMargins:(NSDirectionalEdgeInsets)directionalLayoutMargins
{
    UIEdgeInsets margins = charon_margins_from_directional(directionalLayoutMargins, charon_view_reverses_layout_direction(self));
    self.layoutMargins = margins;
    objc_setAssociatedObject(self, &CharonDirectionalMarginsKey,
                             [NSValue valueWithBytes:&directionalLayoutMargins objCType:@encode(NSDirectionalEdgeInsets)], OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, &CharonProjectedMarginsKey, [NSValue valueWithUIEdgeInsets:margins], OBJC_ASSOCIATION_RETAIN);
}

@end
