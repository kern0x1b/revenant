#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UILayoutGuide (RevenantSafeArea)
- (UIView *)revenant_view;
@end

static char revenant_safe_guide_key;
static char revenant_safe_constraints_key;
static NSHashTable *revenant_safe_owners;

static NSArray *revenant_safe_constraints(UIView *view, UILayoutGuide *guide, UIEdgeInsets insets)
{
    UIView *item = [guide revenant_view];
    NSArray *constraints = @[
        [NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeft multiplier:1 constant:insets.left],
        [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:item attribute:NSLayoutAttributeRight multiplier:1 constant:insets.right],
        [NSLayoutConstraint constraintWithItem:item attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1 constant:insets.top],
        [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:item attribute:NSLayoutAttributeBottom multiplier:1 constant:insets.bottom]
    ];
    if ([constraints.firstObject respondsToSelector:@selector(setIdentifier:)]) {
        NSArray *names = @[@"UIView-leftSafeArea-guide-constraint", @"UIView-rightSafeArea-guide-constraint", @"UIView-topSafeArea-guide-constraint", @"UIView-bottomSafeArea-guide-constraint"];
        for (NSUInteger index = 0; index < 4; index++)
            [constraints[index] setIdentifier:names[index]];
    }
    return constraints;
}

static BOOL revenant_update_safe_area_guide(UIView *view)
{
    NSArray *constraints = objc_getAssociatedObject(view, &revenant_safe_constraints_key);
    if (!constraints)
        return NO;
    UIEdgeInsets insets = view.safeAreaInsets;
    CGFloat constants[] = {insets.left, insets.right, insets.top, insets.bottom};
    BOOL changed = NO;
    for (NSUInteger index = 0; index < 4; index++) {
        NSLayoutConstraint *constraint = constraints[index];
        if (fabs(constraint.constant - constants[index]) > 0.01) {
            constraint.constant = constants[index];
            changed = YES;
        }
    }
    return changed;
}

static void revenant_install_safe_area_updates(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        revenant_safe_owners = [NSHashTable weakObjectsHashTable];
        SEL layout = @selector(layoutSubviews);
        Method layoutMethod = class_getInstanceMethod([UIView class], layout);
        void (*layoutOriginal)(id, SEL) = (void (*)(id, SEL))method_getImplementation(layoutMethod);
        class_replaceMethod([UIView class], layout, imp_implementationWithBlock(^(UIView *self) {
            if (objc_getAssociatedObject(self, &revenant_safe_constraints_key))
                revenant_update_safe_area_guide(self);
            layoutOriginal(self, layout);
        }), method_getTypeEncoding(layoutMethod));
        SEL moved = @selector(didMoveToWindow);
        Method movedMethod = class_getInstanceMethod([UIView class], moved);
        void (*movedOriginal)(id, SEL) = (void (*)(id, SEL))method_getImplementation(movedMethod);
        class_replaceMethod([UIView class], moved, imp_implementationWithBlock(^(UIView *self) {
            movedOriginal(self, moved);
            if (objc_getAssociatedObject(self, &revenant_safe_constraints_key) && revenant_update_safe_area_guide(self))
                [self setNeedsLayout];
        }), method_getTypeEncoding(movedMethod));
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidChangeStatusBarFrameNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            for (UIView *view in [revenant_safe_owners allObjects])
                if (revenant_update_safe_area_guide(view))
                    [view setNeedsLayout];
        }];
    });
}

@implementation UIView (RevenantSafeAreaGuide)

- (UILayoutGuide *)safeAreaLayoutGuide
{
    UILayoutGuide *guide = objc_getAssociatedObject(self, &revenant_safe_guide_key);
    if (guide)
        return guide;
    revenant_install_safe_area_updates();
    guide = [[UILayoutGuide alloc] init];
    guide.identifier = @"UIViewSafeAreaLayoutGuide";
    objc_setAssociatedObject(self, &revenant_safe_guide_key, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addLayoutGuide:guide];
    NSArray *constraints = revenant_safe_constraints(self, guide, self.safeAreaInsets);
    objc_setAssociatedObject(self, &revenant_safe_constraints_key, constraints, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addConstraints:constraints];
    [revenant_safe_owners addObject:self];
    return guide;
}

@end
