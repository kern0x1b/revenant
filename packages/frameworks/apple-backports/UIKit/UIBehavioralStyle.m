#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_preferred_style_key = 0;

static UIBehavioralStyle revenant_preferred_style(id view)
{
    return [objc_getAssociatedObject(view, &revenant_preferred_style_key) unsignedIntegerValue];
}

static void revenant_set_preferred_style(id view, UIBehavioralStyle style)
{
    objc_setAssociatedObject(view, &revenant_preferred_style_key, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIButton (RevenantBehavioralStyle15)

- (UIBehavioralStyle)behavioralStyle
{
    return UIBehavioralStylePad;
}

- (UIBehavioralStyle)preferredBehavioralStyle
{
    return revenant_preferred_style(self);
}

- (void)setPreferredBehavioralStyle:(UIBehavioralStyle)preferredBehavioralStyle
{
    revenant_set_preferred_style(self, preferredBehavioralStyle);
}

@end

@implementation UISlider (RevenantBehavioralStyle15)

- (UIBehavioralStyle)behavioralStyle
{
    return UIBehavioralStylePad;
}

- (UIBehavioralStyle)preferredBehavioralStyle
{
    return revenant_preferred_style(self);
}

- (void)setPreferredBehavioralStyle:(UIBehavioralStyle)preferredBehavioralStyle
{
    revenant_set_preferred_style(self, preferredBehavioralStyle);
}

@end

@implementation UINavigationBar (RevenantBehavioralStyle16)

- (UIBehavioralStyle)behavioralStyle
{
    return UIBehavioralStylePad;
}

- (UIBehavioralStyle)preferredBehavioralStyle
{
    return revenant_preferred_style(self);
}

- (void)setPreferredBehavioralStyle:(UIBehavioralStyle)preferredBehavioralStyle
{
    revenant_set_preferred_style(self, preferredBehavioralStyle);
}

- (UINavigationBarNSToolbarSection)currentNSToolbarSection
{
    return UINavigationBarNSToolbarSectionNone;
}

@end
