#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char RevenantDirectionalMarginsKey;
static char RevenantProjectedMarginsKey;

static BOOL revenant_view_reverses_layout_direction(UIView *view)
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

static UIEdgeInsets revenant_margins_from_directional(NSDirectionalEdgeInsets insets, BOOL reversed)
{
    return reversed ? UIEdgeInsetsMake(insets.top, insets.trailing, insets.bottom, insets.leading)
                    : UIEdgeInsetsMake(insets.top, insets.leading, insets.bottom, insets.trailing);
}

static NSDirectionalEdgeInsets revenant_directional_from_margins(UIEdgeInsets insets, BOOL reversed)
{
    return reversed ? NSDirectionalEdgeInsetsMake(insets.top, insets.right, insets.bottom, insets.left)
                    : NSDirectionalEdgeInsetsMake(insets.top, insets.left, insets.bottom, insets.right);
}

@implementation UIView (RevenantDirectionalLayoutMargins)

- (NSDirectionalEdgeInsets)directionalLayoutMargins
{
    NSValue *directional = objc_getAssociatedObject(self, &RevenantDirectionalMarginsKey);
    NSValue *projected = objc_getAssociatedObject(self, &RevenantProjectedMarginsKey);
    UIEdgeInsets margins = self.layoutMargins;
    if (directional && projected && UIEdgeInsetsEqualToEdgeInsets(projected.UIEdgeInsetsValue, margins)) {
        NSDirectionalEdgeInsets stored = NSDirectionalEdgeInsetsZero;
        [directional getValue:&stored];
        return stored;
    }
    return revenant_directional_from_margins(margins, revenant_view_reverses_layout_direction(self));
}

- (void)setDirectionalLayoutMargins:(NSDirectionalEdgeInsets)directionalLayoutMargins
{
    UIEdgeInsets margins = revenant_margins_from_directional(directionalLayoutMargins, revenant_view_reverses_layout_direction(self));
    self.layoutMargins = margins;
    objc_setAssociatedObject(self, &RevenantDirectionalMarginsKey,
                             [NSValue valueWithBytes:&directionalLayoutMargins objCType:@encode(NSDirectionalEdgeInsets)], OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, &RevenantProjectedMarginsKey, [NSValue valueWithUIEdgeInsets:margins], OBJC_ASSOCIATION_RETAIN);
}

@end
