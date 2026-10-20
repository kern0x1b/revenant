#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface NSLayoutAnchor (RevenantAnchors)
+ (instancetype)revenant_anchorWithItem:(id)item attribute:(NSLayoutAttribute)attribute;
@end

static id revenant_anchor(UIView *view, SEL name, Class type, NSLayoutAttribute attribute)
{
    id anchor = objc_getAssociatedObject(view, name);
    if (!anchor) {
        anchor = [type revenant_anchorWithItem:view attribute:attribute];
        objc_setAssociatedObject(view, name, anchor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return anchor;
}

@implementation UIView (RevenantAnchors)

- (NSLayoutXAxisAnchor *)leadingAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeLeading);
}

- (NSLayoutXAxisAnchor *)trailingAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeTrailing);
}

- (NSLayoutXAxisAnchor *)leftAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeLeft);
}

- (NSLayoutXAxisAnchor *)rightAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeRight);
}

- (NSLayoutYAxisAnchor *)topAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeTop);
}

- (NSLayoutYAxisAnchor *)bottomAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeBottom);
}

- (NSLayoutDimension *)widthAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutDimension class], NSLayoutAttributeWidth);
}

- (NSLayoutDimension *)heightAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutDimension class], NSLayoutAttributeHeight);
}

- (NSLayoutXAxisAnchor *)centerXAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeCenterX);
}

- (NSLayoutYAxisAnchor *)centerYAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeCenterY);
}

- (NSLayoutYAxisAnchor *)firstBaselineAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeFirstBaseline);
}

- (NSLayoutYAxisAnchor *)lastBaselineAnchor
{
    return revenant_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeLastBaseline);
}

@end
