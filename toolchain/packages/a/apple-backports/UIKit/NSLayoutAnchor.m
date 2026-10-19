#import <UIKit/UIKit.h>

BOOL charon_layout_has_baseline(UIView *view);

static BOOL charon_engine_knows_first_baseline(void)
{
    return NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_8_0;
}

static BOOL charon_shows_text(UIView *view)
{
    return [view isKindOfClass:[UILabel class]] || [view isKindOfClass:[UITextField class]] || [view isKindOfClass:[UITextView class]];
}

static UIView *charon_baseline_leaf(UIView *view, BOOL first)
{
    for (NSUInteger depth = 0; depth < 64; depth++) {
        UIView *next = first ? [view viewForFirstBaselineLayout] : [view viewForLastBaselineLayout];
        if (!next || next == view)
            break;
        view = next;
    }
    return view;
}

BOOL charon_layout_has_baseline(UIView *view)
{
    return charon_shows_text(charon_baseline_leaf(view, NO));
}

static void charon_resolve_baseline(id *item, NSLayoutAttribute *attribute)
{
    BOOL first = *attribute == NSLayoutAttributeFirstBaseline;
    if ((!first && *attribute != NSLayoutAttributeLastBaseline) || charon_engine_knows_first_baseline() || ![*item isKindOfClass:[UIView class]])
        return;
    UIView *view = charon_baseline_leaf(*item, first);
    *item = view;
    if (charon_shows_text(view))
        *attribute = NSLayoutAttributeBaseline;
    else
        *attribute = first ? NSLayoutAttributeTop : NSLayoutAttributeBottom;
}

static int charon_unit(NSLayoutAttribute attribute)
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

static BOOL charon_compatible(NSLayoutAttribute first, NSLayoutAttribute second)
{
    int a = charon_unit(first), b = charon_unit(second);
    if (a <= 3 && b <= 3)
        return a == 3 || b == 3 || a == b;
    return a == b;
}

static NSString *charon_attribute_name(NSLayoutAttribute attribute)
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

+ (instancetype)charon_anchorWithItem:(id)item attribute:(NSLayoutAttribute)attribute
{
    NSLayoutAnchor *anchor = [[self alloc] init];
    anchor->_item = item;
    anchor->_attribute = attribute;
    return anchor;
}

static NSLayoutConstraint *charon_constraint(NSLayoutAnchor *anchor, NSLayoutRelation relation, NSLayoutAnchor *other, CGFloat multiplier, CGFloat constant)
{
    if (other && !charon_compatible(anchor->_attribute, other->_attribute))
        [NSException raise:NSInvalidArgumentException format:@"NSLayoutConstraint for %@: A constraint cannot be made between %@ and %@ because their units are not compatible.", anchor, anchor, other];
    id firstItem = anchor->_item, secondItem = other ? other->_item : nil;
    NSLayoutAttribute firstAttribute = anchor->_attribute, secondAttribute = other ? other->_attribute : NSLayoutAttributeNotAnAttribute;
    charon_resolve_baseline(&firstItem, &firstAttribute);
    if (secondItem)
        charon_resolve_baseline(&secondItem, &secondAttribute);
    return [NSLayoutConstraint constraintWithItem:firstItem attribute:firstAttribute relatedBy:relation toItem:secondItem attribute:secondAttribute multiplier:multiplier constant:constant];
}

- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)anchor
{
    return charon_constraint(self, NSLayoutRelationEqual, anchor, 1, 0);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)anchor
{
    return charon_constraint(self, NSLayoutRelationGreaterThanOrEqual, anchor, 1, 0);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)anchor
{
    return charon_constraint(self, NSLayoutRelationLessThanOrEqual, anchor, 1, 0);
}

- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationEqual, anchor, 1, c);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationGreaterThanOrEqual, anchor, 1, c);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationLessThanOrEqual, anchor, 1, c);
}

- (NSString *)description
{
    id item = _item;
    return [NSString stringWithFormat:@"<%@:%p \"%@:%p.%@\">", [self class], self, [item class], item, charon_attribute_name(_attribute)];
}

@end

@implementation NSLayoutXAxisAnchor
@end

@implementation NSLayoutYAxisAnchor
@end

@implementation NSLayoutDimension

- (NSLayoutConstraint *)constraintEqualToConstant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationEqual, nil, 1, c);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToConstant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationGreaterThanOrEqual, nil, 1, c);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToConstant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationLessThanOrEqual, nil, 1, c);
}

- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m
{
    return charon_constraint(self, NSLayoutRelationEqual, anchor, m, 0);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m
{
    return charon_constraint(self, NSLayoutRelationGreaterThanOrEqual, anchor, m, 0);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m
{
    return charon_constraint(self, NSLayoutRelationLessThanOrEqual, anchor, m, 0);
}

- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m constant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationEqual, anchor, m, c);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m constant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationGreaterThanOrEqual, anchor, m, c);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutDimension *)anchor multiplier:(CGFloat)m constant:(CGFloat)c
{
    return charon_constraint(self, NSLayoutRelationLessThanOrEqual, anchor, m, c);
}

@end
