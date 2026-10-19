#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// Only a Mac application draws the mac style; on a phone or tablet every control
// resolves to pad, whatever it was asked for. What was asked is kept.
static const char charon_preferred_style_key = 0;

static UIBehavioralStyle charon_preferred_style(id view)
{
    return [objc_getAssociatedObject(view, &charon_preferred_style_key) unsignedIntegerValue];
}

static void charon_set_preferred_style(id view, UIBehavioralStyle style)
{
    objc_setAssociatedObject(view, &charon_preferred_style_key, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIButton (CharonBehavioralStyle15)

- (UIBehavioralStyle)behavioralStyle
{
    return UIBehavioralStylePad;
}

- (UIBehavioralStyle)preferredBehavioralStyle
{
    return charon_preferred_style(self);
}

- (void)setPreferredBehavioralStyle:(UIBehavioralStyle)preferredBehavioralStyle
{
    charon_set_preferred_style(self, preferredBehavioralStyle);
}

@end

@implementation UISlider (CharonBehavioralStyle15)

- (UIBehavioralStyle)behavioralStyle
{
    return UIBehavioralStylePad;
}

- (UIBehavioralStyle)preferredBehavioralStyle
{
    return charon_preferred_style(self);
}

- (void)setPreferredBehavioralStyle:(UIBehavioralStyle)preferredBehavioralStyle
{
    charon_set_preferred_style(self, preferredBehavioralStyle);
}

@end

@implementation UINavigationBar (CharonBehavioralStyle16)

- (UIBehavioralStyle)behavioralStyle
{
    return UIBehavioralStylePad;
}

- (UIBehavioralStyle)preferredBehavioralStyle
{
    return charon_preferred_style(self);
}

- (void)setPreferredBehavioralStyle:(UIBehavioralStyle)preferredBehavioralStyle
{
    charon_set_preferred_style(self, preferredBehavioralStyle);
}

// A phone or tablet has no NSToolbar for the bar's contents to be in.
- (UINavigationBarNSToolbarSection)currentNSToolbarSection
{
    return UINavigationBarNSToolbarSectionNone;
}

@end
