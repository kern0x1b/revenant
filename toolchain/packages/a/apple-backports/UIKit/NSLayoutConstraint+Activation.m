#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UIView *revenant_item_view(id item)
{
    return [item isKindOfClass:[UILayoutGuide class]] ? [(UILayoutGuide *)item owningView] : item;
}

static UIView *revenant_container(NSLayoutConstraint *constraint)
{
    for (UIView *view = revenant_item_view(constraint.firstItem); view; view = view.superview) {
        if ([view.constraints indexOfObjectIdenticalTo:constraint] != NSNotFound)
            return view;
    }
    return nil;
}

static UIView *revenant_common_ancestor(UIView *first, UIView *second)
{
    if (!second)
        return first;
    for (UIView *candidate = first; candidate; candidate = candidate.superview) {
        if ([second isDescendantOfView:candidate])
            return candidate;
    }
    return nil;
}

@interface NSObject (RevenantGuideBacking)
- (UILayoutGuide *)revenant_guide;
@end

static UILayoutGuide *revenant_guide(id item)
{
    return [item respondsToSelector:@selector(revenant_guide)] ? [item revenant_guide] : nil;
}

static BOOL revenant_ownerless(id item)
{
    UILayoutGuide *guide = [item isKindOfClass:[UILayoutGuide class]] ? item : revenant_guide(item);
    return guide && !guide.owningView;
}

static UIView *revenant_holder(UIView *ancestor)
{
    UILayoutGuide *guide = revenant_guide(ancestor);
    return guide ? guide.owningView : ancestor;
}

@implementation NSLayoutConstraint (RevenantActivation)

+ (void)activateConstraints:(NSArray *)constraints
{
    for (NSLayoutConstraint *constraint in constraints)
        [constraint setActive:YES];
}

+ (void)deactivateConstraints:(NSArray *)constraints
{
    for (NSLayoutConstraint *constraint in constraints)
        [constraint setActive:NO];
}

- (BOOL)isActive
{
    return revenant_container(self) != nil;
}

- (void)setActive:(BOOL)active
{
    UIView *container = revenant_container(self);
    if (!active) {
        [container removeConstraint:self];
        return;
    }
    if (container || revenant_ownerless(self.firstItem) || revenant_ownerless(self.secondItem))
        return;
    UIView *ancestor = revenant_common_ancestor(revenant_item_view(self.firstItem), revenant_item_view(self.secondItem));
    if (!ancestor)
        [NSException raise:NSGenericException format:@"Unable to activate constraint with items %@ and %@ because they have no common ancestor.  Does the constraint reference items in different view hierarchies?  That's illegal.", self.firstItem, self.secondItem];
    [revenant_holder(ancestor) addConstraint:self];
}

@end

@interface UILayoutGuide (RevenantBacking)
- (UIView *)revenant_view;
@end

@interface RevenantConstraintGuideItems : NSObject
@end

@implementation RevenantConstraintGuideItems

static id revenant_backing(id item)
{
    return [item isKindOfClass:[UILayoutGuide class]] ? [(UILayoutGuide *)item revenant_view] : item;
}

static void revenant_swap_constructor(SEL selector, IMP (^make)(IMP original))
{
    Method method = class_getClassMethod([NSLayoutConstraint class], selector);
    if (!method)
        return;
    class_replaceMethod(object_getClass([NSLayoutConstraint class]), selector, make(method_getImplementation(method)), method_getTypeEncoding(method));
}

+ (void)load
{
    revenant_swap_constructor(@selector(constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:), ^IMP(IMP original) {
        SEL selector = @selector(constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:);
        return imp_implementationWithBlock(^NSLayoutConstraint *(Class self, id first, NSLayoutAttribute firstAttribute, NSLayoutRelation relation, id second, NSLayoutAttribute secondAttribute, CGFloat multiplier, CGFloat constant) {
            return ((NSLayoutConstraint *(*)(id, SEL, id, NSLayoutAttribute, NSLayoutRelation, id, NSLayoutAttribute, CGFloat, CGFloat))original)(self, selector, revenant_backing(first), firstAttribute, relation, revenant_backing(second), secondAttribute, multiplier, constant);
        });
    });
    revenant_swap_constructor(@selector(constraintWithItem:attribute:relatedBy:toItem:attribute:constant:), ^IMP(IMP original) {
        SEL selector = @selector(constraintWithItem:attribute:relatedBy:toItem:attribute:constant:);
        return imp_implementationWithBlock(^NSLayoutConstraint *(Class self, id first, NSLayoutAttribute firstAttribute, NSLayoutRelation relation, id second, NSLayoutAttribute secondAttribute, CGFloat constant) {
            return ((NSLayoutConstraint *(*)(id, SEL, id, NSLayoutAttribute, NSLayoutRelation, id, NSLayoutAttribute, CGFloat))original)(self, selector, revenant_backing(first), firstAttribute, relation, revenant_backing(second), secondAttribute, constant);
        });
    });
    revenant_swap_constructor(@selector(constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:), ^IMP(IMP original) {
        SEL selector = @selector(constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:);
        return imp_implementationWithBlock(^NSLayoutConstraint *(Class self, id first, NSLayoutAttribute firstAttribute, NSLayoutRelation relation, id second, NSLayoutAttribute secondAttribute, CGFloat multiplier) {
            return ((NSLayoutConstraint *(*)(id, SEL, id, NSLayoutAttribute, NSLayoutRelation, id, NSLayoutAttribute, CGFloat))original)(self, selector, revenant_backing(first), firstAttribute, relation, revenant_backing(second), secondAttribute, multiplier);
        });
    });
    revenant_swap_constructor(@selector(constraintWithItem:attribute:relatedBy:toItem:attribute:), ^IMP(IMP original) {
        SEL selector = @selector(constraintWithItem:attribute:relatedBy:toItem:attribute:);
        return imp_implementationWithBlock(^NSLayoutConstraint *(Class self, id first, NSLayoutAttribute firstAttribute, NSLayoutRelation relation, id second, NSLayoutAttribute secondAttribute) {
            return ((NSLayoutConstraint *(*)(id, SEL, id, NSLayoutAttribute, NSLayoutRelation, id, NSLayoutAttribute))original)(self, selector, revenant_backing(first), firstAttribute, relation, revenant_backing(second), secondAttribute);
        });
    });
    revenant_swap_constructor(@selector(constraintWithItem:attribute:relatedBy:constant:), ^IMP(IMP original) {
        SEL selector = @selector(constraintWithItem:attribute:relatedBy:constant:);
        return imp_implementationWithBlock(^NSLayoutConstraint *(Class self, id first, NSLayoutAttribute firstAttribute, NSLayoutRelation relation, CGFloat constant) {
            return ((NSLayoutConstraint *(*)(id, SEL, id, NSLayoutAttribute, NSLayoutRelation, CGFloat))original)(self, selector, revenant_backing(first), firstAttribute, relation, constant);
        });
    });
    revenant_swap_constructor(@selector(constraintsWithVisualFormat:options:metrics:views:), ^IMP(IMP original) {
        SEL selector = @selector(constraintsWithVisualFormat:options:metrics:views:);
        return imp_implementationWithBlock(^NSArray *(Class self, NSString *format, NSLayoutFormatOptions options, NSDictionary *metrics, NSDictionary *views) {
            BOOL hasGuide = NO;
            for (id item in views.allValues)
                if ([item isKindOfClass:[UILayoutGuide class]])
                    hasGuide = YES;
            if (hasGuide) {
                NSMutableDictionary *mapped = [NSMutableDictionary dictionaryWithCapacity:views.count];
                for (NSString *key in views)
                    mapped[key] = revenant_backing(views[key]);
                views = mapped;
            }
            return ((NSArray *(*)(id, SEL, NSString *, NSLayoutFormatOptions, NSDictionary *, NSDictionary *))original)(self, selector, format, options, metrics, views);
        });
    });
}

@end
