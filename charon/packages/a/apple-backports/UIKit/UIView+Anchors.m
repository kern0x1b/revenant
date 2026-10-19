#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface NSLayoutAnchor (CharonAnchors)
+ (instancetype)charon_anchorWithItem:(id)item attribute:(NSLayoutAttribute)attribute;
@end

static id charon_anchor(UIView *view, SEL name, Class type, NSLayoutAttribute attribute)
{
    id anchor = objc_getAssociatedObject(view, name);
    if (!anchor) {
        anchor = [type charon_anchorWithItem:view attribute:attribute];
        objc_setAssociatedObject(view, name, anchor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return anchor;
}

@implementation UIView (CharonAnchors)

- (NSLayoutXAxisAnchor *)leadingAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeLeading);
}

- (NSLayoutXAxisAnchor *)trailingAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeTrailing);
}

- (NSLayoutXAxisAnchor *)leftAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeLeft);
}

- (NSLayoutXAxisAnchor *)rightAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeRight);
}

- (NSLayoutYAxisAnchor *)topAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeTop);
}

- (NSLayoutYAxisAnchor *)bottomAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeBottom);
}

- (NSLayoutDimension *)widthAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutDimension class], NSLayoutAttributeWidth);
}

- (NSLayoutDimension *)heightAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutDimension class], NSLayoutAttributeHeight);
}

- (NSLayoutXAxisAnchor *)centerXAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeCenterX);
}

- (NSLayoutYAxisAnchor *)centerYAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeCenterY);
}

- (NSLayoutYAxisAnchor *)firstBaselineAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeFirstBaseline);
}

- (NSLayoutYAxisAnchor *)lastBaselineAnchor
{
    return charon_anchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeLastBaseline);
}

@end
