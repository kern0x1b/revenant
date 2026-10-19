#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonInteractionsKey;

static NSMutableArray *charon_interactions(UIView *view, BOOL create)
{
    NSMutableArray *held = objc_getAssociatedObject(view, &CharonInteractionsKey);
    if (!held && create) {
        held = [NSMutableArray array];
        objc_setAssociatedObject(view, &CharonInteractionsKey, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return held;
}

static void charon_needs(BOOL held, NSString *condition)
{
    if (!held)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: %@", condition];
}

static void charon_moved(id<UIInteraction> interaction, UIView *view)
{
    [interaction willMoveToView:view];
    [interaction didMoveToView:view];
}

@implementation UIView (CharonInteractions)

- (NSArray<id<UIInteraction>> *)interactions
{
    NSMutableArray *held = charon_interactions(self, NO);
    return held ? [NSArray arrayWithArray:held] : [NSArray array];
}

- (void)setInteractions:(NSArray<id<UIInteraction>> *)interactions
{
    charon_needs(interactions != nil, @"interactions");
    NSArray *wanted = [interactions copy];
    for (id<UIInteraction> interaction in [self interactions])
        [self removeInteraction:interaction];
    for (id<UIInteraction> interaction in wanted)
        [self addInteraction:interaction];
}

// An interaction is held once: adding one a view already holds leaves the list as it was and tells
// the interaction's view, which is what the host's own UIKit does, and one that is held elsewhere
// is moved rather than duplicated. A nil interaction is refused with the same exception and the same
// message the host raises.
- (void)addInteraction:(id<UIInteraction>)interaction
{
    charon_needs(interaction != nil, @"interaction != nil");
    UIView *held = interaction.view;
    if (held == self)
        return;
    if (held)
        [held removeInteraction:interaction];
    NSMutableArray *list = charon_interactions(self, YES);
    if ([list indexOfObjectIdenticalTo:interaction] != NSNotFound) {
        charon_moved(interaction, self);
        return;
    }
    [list addObject:interaction];
    charon_moved(interaction, self);
}

// Removing one the view does not hold is quietly nothing, as on the host; removing a nil one is
// refused the same way adding a nil one is.
- (void)removeInteraction:(id<UIInteraction>)interaction
{
    charon_needs(interaction != nil, @"interaction != nil");
    NSMutableArray *held = charon_interactions(self, NO);
    NSUInteger index = held ? [held indexOfObjectIdenticalTo:interaction] : NSNotFound;
    if (index == NSNotFound)
        return;
    [held removeObjectAtIndex:index];
    charon_moved(interaction, nil);
}

@end
