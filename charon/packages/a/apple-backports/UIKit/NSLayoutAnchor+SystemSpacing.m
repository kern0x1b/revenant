#import <UIKit/UIKit.h>

static const CGFloat CharonSystemSpacing = 8;

static UIFont *charon_font_of(id item)
{
    return [item respondsToSelector:@selector(font)] ? [item font] : nil;
}

static BOOL charon_is_baseline(NSLayoutAttribute attribute)
{
    return attribute == NSLayoutAttributeFirstBaseline || attribute == NSLayoutAttributeLastBaseline ||
           attribute == NSLayoutAttributeBaseline;
}

static CGFloat charon_baseline_spacing(UIFont *below, UIFont *above)
{
    CGFloat value = below.lineHeight + below.descender - above.descender;
    CGFloat scale = [UIScreen mainScreen].scale;
    if (scale <= 0)
        scale = 1;
    return ceil(value * scale) / scale;
}

static NSLayoutConstraint *charon_system_spacing_constraint(NSLayoutAnchor *anchor, NSLayoutAnchor *other,
                                                            CGFloat multiplier, NSLayoutRelation relation)
{
    NSLayoutConstraint *shape = [anchor constraintEqualToAnchor:other];
    CGFloat spacing = CharonSystemSpacing;
    if (charon_is_baseline(shape.firstAttribute) || charon_is_baseline(shape.secondAttribute)) {
        UIFont *below = charon_font_of(shape.firstItem), *above = charon_font_of(shape.secondItem);
        if (below && above)
            spacing = charon_baseline_spacing(below, above);
    }
    CGFloat constant = spacing * multiplier;
    if (constant < 0)
        constant = 0;
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:shape.firstItem attribute:shape.firstAttribute
                                                                 relatedBy:relation toItem:shape.secondItem
                                                                 attribute:shape.secondAttribute multiplier:1
                                                                  constant:constant];
    constraint.priority = shape.priority;
    return constraint;
}

@implementation NSLayoutXAxisAnchor (CharonSystemSpacing)

- (NSLayoutConstraint *)constraintEqualToSystemSpacingAfterAnchor:(NSLayoutXAxisAnchor *)anchor multiplier:(CGFloat)multiplier
{
    return charon_system_spacing_constraint(self, anchor, multiplier, NSLayoutRelationEqual);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToSystemSpacingAfterAnchor:(NSLayoutXAxisAnchor *)anchor multiplier:(CGFloat)multiplier
{
    return charon_system_spacing_constraint(self, anchor, multiplier, NSLayoutRelationGreaterThanOrEqual);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToSystemSpacingAfterAnchor:(NSLayoutXAxisAnchor *)anchor multiplier:(CGFloat)multiplier
{
    return charon_system_spacing_constraint(self, anchor, multiplier, NSLayoutRelationLessThanOrEqual);
}

@end

@implementation NSLayoutYAxisAnchor (CharonSystemSpacing)

- (NSLayoutConstraint *)constraintEqualToSystemSpacingBelowAnchor:(NSLayoutYAxisAnchor *)anchor multiplier:(CGFloat)multiplier
{
    return charon_system_spacing_constraint(self, anchor, multiplier, NSLayoutRelationEqual);
}

- (NSLayoutConstraint *)constraintGreaterThanOrEqualToSystemSpacingBelowAnchor:(NSLayoutYAxisAnchor *)anchor multiplier:(CGFloat)multiplier
{
    return charon_system_spacing_constraint(self, anchor, multiplier, NSLayoutRelationGreaterThanOrEqual);
}

- (NSLayoutConstraint *)constraintLessThanOrEqualToSystemSpacingBelowAnchor:(NSLayoutYAxisAnchor *)anchor multiplier:(CGFloat)multiplier
{
    return charon_system_spacing_constraint(self, anchor, multiplier, NSLayoutRelationLessThanOrEqual);
}

@end
