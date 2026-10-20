#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UILayoutGuide (RevenantLayoutGuides)
- (UIView *)revenant_view;
- (void)setOwningView:(UIView *)owningView;
@end

static char revenant_guides_key;
static char revenant_margins_guide_key;
static char revenant_margins_constraints_key;
static char revenant_readable_guide_key;

static const CGFloat revenant_readable_width = 672;

static BOOL revenant_engine_knows_margins(void)
{
    return NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_8_0;
}

static NSLayoutConstraint *revenant_identified(NSLayoutConstraint *constraint, NSString *identifier)
{
    if ([constraint respondsToSelector:@selector(setIdentifier:)])
        [constraint setIdentifier:identifier];
    return constraint;
}

static NSArray *revenant_margins_constraints(UIView *view, UILayoutGuide *guide)
{
    UIView *item = [guide revenant_view];
    if (revenant_engine_knows_margins()) {
        return @[
            revenant_identified([NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeftMargin multiplier:1 constant:0], @"UIView-leftMargin-guide-constraint"),
            revenant_identified([NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeRightMargin multiplier:1 constant:0], @"UIView-rightMargin-guide-constraint"),
            revenant_identified([NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTopMargin multiplier:1 constant:0], @"UIView-topMargin-guide-constraint"),
            revenant_identified([NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeBottomMargin multiplier:1 constant:0], @"UIView-bottomMargin-guide-constraint")
        ];
    }
    UIEdgeInsets margins = [view layoutMargins];
    return @[
        revenant_identified([NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeft multiplier:1 constant:margins.left], @"UIView-leftMargin-guide-constraint"),
        revenant_identified([NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:item attribute:NSLayoutAttributeRight multiplier:1 constant:margins.right], @"UIView-rightMargin-guide-constraint"),
        revenant_identified([NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1 constant:margins.top], @"UIView-topMargin-guide-constraint"),
        revenant_identified([NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:item attribute:NSLayoutAttributeBottom multiplier:1 constant:margins.bottom], @"UIView-bottomMargin-guide-constraint")
    ];
}

@implementation UIView (RevenantLayoutGuides)

- (NSArray *)layoutGuides
{
    NSArray *guides = objc_getAssociatedObject(self, &revenant_guides_key);
    return guides ? [guides copy] : @[];
}

- (void)addLayoutGuide:(UILayoutGuide *)layoutGuide
{
    UIView *previous = layoutGuide.owningView;
    if (previous == self)
        return;
    [previous removeLayoutGuide:layoutGuide];
    NSMutableArray *guides = objc_getAssociatedObject(self, &revenant_guides_key);
    if (!guides) {
        guides = [NSMutableArray array];
        objc_setAssociatedObject(self, &revenant_guides_key, guides, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [guides addObject:layoutGuide];
    [layoutGuide setOwningView:self];
}

- (void)removeLayoutGuide:(UILayoutGuide *)layoutGuide
{
    NSMutableArray *guides = objc_getAssociatedObject(self, &revenant_guides_key);
    if ([guides indexOfObjectIdenticalTo:layoutGuide] == NSNotFound)
        return;
    [layoutGuide setOwningView:nil];
    [guides removeObjectIdenticalTo:layoutGuide];
}

- (UILayoutGuide *)layoutMarginsGuide
{
    UILayoutGuide *guide = objc_getAssociatedObject(self, &revenant_margins_guide_key);
    if (!guide) {
        guide = [[UILayoutGuide alloc] init];
        guide.identifier = @"UIViewLayoutMarginsGuide";
        objc_setAssociatedObject(self, &revenant_margins_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self addLayoutGuide:guide];
        [self revenant_updateLayoutMarginsGuide];
    }
    return guide;
}

- (void)revenant_updateLayoutMarginsGuide
{
    UILayoutGuide *guide = objc_getAssociatedObject(self, &revenant_margins_guide_key);
    if (!guide)
        return;
    if ([guide revenant_view].superview != self)
        [guide setOwningView:self];
    NSArray *constraints = objc_getAssociatedObject(self, &revenant_margins_constraints_key);
    if (constraints && revenant_engine_knows_margins() && [self.constraints indexOfObjectIdenticalTo:constraints[0]] != NSNotFound)
        return;
    if (constraints && [self.constraints indexOfObjectIdenticalTo:constraints[0]] != NSNotFound) {
        UIEdgeInsets margins = [self layoutMargins];
        CGFloat constants[] = {margins.left, margins.right, margins.top, margins.bottom};
        for (NSUInteger index = 0; index < 4; index++)
            [constraints[index] setConstant:constants[index]];
        return;
    }
    if (constraints)
        [self removeConstraints:constraints];
    constraints = revenant_margins_constraints(self, guide);
    objc_setAssociatedObject(self, &revenant_margins_constraints_key, constraints, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addConstraints:constraints];
}

- (UILayoutGuide *)readableContentGuide
{
    UILayoutGuide *guide = objc_getAssociatedObject(self, &revenant_readable_guide_key);
    if (guide)
        return guide;
    UILayoutGuide *margins = [self layoutMarginsGuide];
    guide = [[UILayoutGuide alloc] init];
    guide.identifier = @"UIViewReadableContentGuide";
    objc_setAssociatedObject(self, &revenant_readable_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addLayoutGuide:guide];
    NSLayoutConstraint *width = revenant_identified([guide.widthAnchor constraintEqualToConstant:revenant_readable_width], @"UIView-width-readableContentGuide-constraint");
    width.priority = 999.5;
    [self addConstraints:@[
        revenant_identified([guide.leadingAnchor constraintGreaterThanOrEqualToAnchor:margins.leadingAnchor], @"UIView-leadingMargin-readableContentGuide-constraint"),
        revenant_identified([margins.trailingAnchor constraintGreaterThanOrEqualToAnchor:guide.trailingAnchor], @"UIView-trailingMargin-readableContentGuide-constraint"),
        revenant_identified([guide.centerXAnchor constraintEqualToAnchor:margins.centerXAnchor], @"UIView-centerX-readableContentGuide-constraint"),
        revenant_identified([guide.topAnchor constraintEqualToAnchor:margins.topAnchor], @"UIView-top-readableContentGuide-constraint"),
        revenant_identified([margins.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor], @"UIView-bottom-readableContentGuide-constraint"),
        width
    ]];
    return guide;
}

@end
