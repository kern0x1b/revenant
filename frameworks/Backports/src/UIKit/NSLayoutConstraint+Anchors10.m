#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface NSLayoutAnchor (RevenantItems)
+ (instancetype)revenant_anchorWithItem:(id)item attribute:(NSLayoutAttribute)attribute;
@end

static NSLayoutAnchor *revenant_anchor(id item, NSLayoutAttribute attribute)
{
    if (!item)
        return nil;
    Class kind = nil;
    switch (attribute) {
    case NSLayoutAttributeLeft:
    case NSLayoutAttributeRight:
    case NSLayoutAttributeLeading:
    case NSLayoutAttributeTrailing:
    case NSLayoutAttributeCenterX:
        kind = [NSLayoutXAxisAnchor class];
        break;
    case NSLayoutAttributeTop:
    case NSLayoutAttributeBottom:
    case NSLayoutAttributeCenterY:
    case NSLayoutAttributeFirstBaseline:
    case NSLayoutAttributeLastBaseline:
        kind = [NSLayoutYAxisAnchor class];
        break;
    case NSLayoutAttributeWidth:
    case NSLayoutAttributeHeight:
        kind = [NSLayoutDimension class];
        break;
    default:
        return nil;
    }
    return [kind revenant_anchorWithItem:item attribute:attribute];
}

@implementation NSLayoutConstraint (RevenantAnchors10)

- (NSLayoutAnchor *)firstAnchor
{
    return revenant_anchor(self.firstItem, self.firstAttribute);
}

- (NSLayoutAnchor *)secondAnchor
{
    return revenant_anchor(self.secondItem, self.secondAttribute);
}

@end
