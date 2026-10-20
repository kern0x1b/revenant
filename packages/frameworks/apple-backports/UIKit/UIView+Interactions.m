#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantInteractionsKey;

static NSMutableArray *revenant_interactions(UIView *view, BOOL create)
{
    NSMutableArray *held = objc_getAssociatedObject(view, &RevenantInteractionsKey);
    if (!held && create) {
        held = [NSMutableArray array];
        objc_setAssociatedObject(view, &RevenantInteractionsKey, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return held;
}

static void revenant_needs(BOOL held, NSString *condition)
{
    if (!held)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: %@", condition];
}

static void revenant_moved(id<UIInteraction> interaction, UIView *view)
{
    [interaction willMoveToView:view];
    [interaction didMoveToView:view];
}

@implementation UIView (RevenantInteractions)

- (NSArray<id<UIInteraction>> *)interactions
{
    NSMutableArray *held = revenant_interactions(self, NO);
    return held ? [NSArray arrayWithArray:held] : [NSArray array];
}

- (void)setInteractions:(NSArray<id<UIInteraction>> *)interactions
{
    revenant_needs(interactions != nil, @"interactions");
    NSArray *wanted = [interactions copy];
    for (id<UIInteraction> interaction in [self interactions])
        [self removeInteraction:interaction];
    for (id<UIInteraction> interaction in wanted)
        [self addInteraction:interaction];
}

- (void)addInteraction:(id<UIInteraction>)interaction
{
    revenant_needs(interaction != nil, @"interaction != nil");
    UIView *held = interaction.view;
    if (held == self)
        return;
    if (held)
        [held removeInteraction:interaction];
    NSMutableArray *list = revenant_interactions(self, YES);
    if ([list indexOfObjectIdenticalTo:interaction] != NSNotFound) {
        revenant_moved(interaction, self);
        return;
    }
    [list addObject:interaction];
    revenant_moved(interaction, self);
}

- (void)removeInteraction:(id<UIInteraction>)interaction
{
    revenant_needs(interaction != nil, @"interaction != nil");
    NSMutableArray *held = revenant_interactions(self, NO);
    NSUInteger index = held ? [held indexOfObjectIdenticalTo:interaction] : NSNotFound;
    if (index == NSNotFound)
        return;
    [held removeObjectAtIndex:index];
    revenant_moved(interaction, nil);
}

@end
