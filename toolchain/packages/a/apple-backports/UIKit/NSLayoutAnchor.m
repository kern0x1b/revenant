#import <UIKit/UIKit.h>

BOOL revenant_layout_has_baseline(UIView *view);

static BOOL revenant_engine_knows_first_baseline(void)
{
    return NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_8_0;
}

static BOOL revenant_shows_text(UIView *view)
{
    return [view isKindOfClass:[UILabel class]] || [view isKindOfClass:[UITextField class]] || [view isKindOfClass:[UITextView class]];
}

static UIView *revenant_baseline_leaf(UIView *view, BOOL first)
{
    for (NSUInteger depth = 0; depth < 64; depth++) {
        UIView *next = first ? [view viewForFirstBaselineLayout] : [view viewForLastBaselineLayout];
        if (!next || next == view)
            break;
        view = next;
    }
    return view;
}

BOOL revenant_layout_has_baseline(UIView *view)
{
    return revenant_shows_text(revenant_baseline_leaf(view, NO));
}

static void revenant_resolve_baseline(id *item, NSLayoutAttribute *attribute)
{
    BOOL first = *attribute == NSLayoutAttributeFirstBaseline;
    if ((!first && *attribute != NSLayoutAttributeLastBaseline) || revenant_engine_knows_first_baseline() || ![*item isKindOfClass:[UIView class]])
        return;
    UIView *view = revenant_baseline_leaf(*item, first);
    *item = view;
    if (revenant_shows_text(view))
        *attribute = NSLayoutAttributeBaseline;
    else
        *attribute = first ? NSLayoutAttributeTop : NSLayoutAttributeBottom;
}

static int revenant_unit(NSLayoutAttribute attribute)
{
    switch (attribute) {
    case NSLayoutAttributeLeading:
    case NSLayoutAttributeTrailing:
        return 1;
    case NSLayoutAttributeLeft:
    case NSLayoutAttributeRight:
        return 2;
    case NSLayoutAttributeCenterX:
        return 3;
    case NSLayoutAttributeWidth:
    case NSLayoutAttributeHeight:
        return 5;
    default:
        return 4;
    }
}

static BOOL revenant_compatible(NSLayoutAttribute first, NSLayoutAttribute second)
{
    int a = revenant_unit(first), b = revenant_unit(second);
    if (a <= 3 && b <= 3)
        return a == 3 || b == 3 || a == b;
    return a == b;
}

static NSString *revenant_attribute_name(NSLayoutAttribute attribute)
{
    switch (attribute) {
    case NSLayoutAttributeLeft: return @"left";
    case NSLayoutAttributeRight: return @"right";
    case NSLayoutAttributeTop: return @"top";
    case NSLayoutAttributeBottom: return @"bottom";
    case NSLayoutAttributeLeading: return @"leading";
    case NSLayoutAttributeTrailing: return @"trailing";
    case NSLayoutAttributeWidth: return @"width";
    case NSLayoutAttributeHeight: return @"height";
    case NSLayoutAttributeCenterX: return @"centerX";
    case NSLayoutAttributeCenterY: return @"centerY";
    case NSLayoutAttributeLastBaseline: return @"lastBaseline";
    case NSLayoutAttributeFirstBaseline: return @"firstBaseline";
    default: return @"notAnAttribute";
    }
}

@implementation NSLayoutAnchor {
    __weak id _item;
    NSLayoutAttribute _attribute;
}

+ (instancetype)revenant_anchorWithItem:(id)item attribute:(NSLayoutAttribute)attribute
{
    NSLayoutAnchor *anchor = [[self alloc] init];
    anchor->_item = item;
    anchor->_attribute = attribute;
    return anchor;
}

static NSLayoutConstraint *revenant_constraint(NSLayoutAnchor *anchor, NSLayoutRelation relation, NSLayoutAnchor *other, CGFloat multiplier, CGFloat constant)
{
    if (other && !revenant_compatible(anchor->_attribute, other->_attribute))
        [NSException raise:NSInvalidArgumentException format:@"NSLayoutConstraint for %@: A constraint cannot be made between %@ and %@ because their units are not compatible.", anchor, anchor, other];
    id firstItem = anchor->_item, secondItem = other ? other->_item : nil;
    NSLayoutAttribute firstAttribute = anchor->_attribute, secondAttribute = other ? other->_attribute : NSLayoutAttributeNotAnAttribute;
    revenant_resolve_baseline(&firstItem, &firstAttribute);
    if (secondItem)
        revenant_resolve_baseline(&secondItem, &secondAttribute);
    return [NSLayoutConstraint constraintWithItem:firstItem attribute:firstAttribute relatedBy:relation toItem:secondItem attribute:secondAttribute multiplier:multiplier constant:constant];
}

- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)anchor
{
    return revenant_constraint(self, NSLayoutRelationEqual, anchor, 1, 0);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)anchor
{
    return revenant_constraint(self, NSLayoutRelationGreaterThanOrEqual, anchor, 1, 0);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)anchor
{
    return revenant_constraint(self, NSLayoutRelationLessThanOrEqual, anchor, 1, 0);
}

- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationEqual, anchor, 1, c);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationGreaterThanOrEqual, anchor, 1, c);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationLessThanOrEqual, anchor, 1, c);
}

- (NSString *)description
{
    id item = _item;
    return [NSString stringWithFormat:@"<%@:%p \"%@:%p.%@\">", [self class], self, [item class], item, revenant_attribute_name(_attribute)];
}

@end

@implementation NSLayoutXAxisAnchor
@end

@implementation NSLayoutYAxisAnchor
@end

@implementation NSLayoutDimension

- (NSLayoutConstraint *)constraintEqualToConstant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationEqual, nil, 1, c);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToConstant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationGreaterThanOrEqual, nil, 1, c);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToConstant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationLessThanOrEqual, nil, 1, c);
}

- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m
{
    return revenant_constraint(self, NSLayoutRelationEqual, anchor, m, 0);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m
{
    return revenant_constraint(self, NSLayoutRelationGreaterThanOrEqual, anchor, m, 0);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m
{
    return revenant_constraint(self, NSLayoutRelationLessThanOrEqual, anchor, m, 0);
}

- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m constant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationEqual, anchor, m, c);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m constant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationGreaterThanOrEqual, anchor, m, c);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m constant:(CGFloat)c
{
    return revenant_constraint(self, NSLayoutRelationLessThanOrEqual, anchor, m, c);
}

@end
