#import "CharonDynamics.h"

// A behavior is primitive (the concrete classes: it holds items) or composite (UIDynamicBehavior itself
// and every subclass an application writes: it holds child behaviors), never both, as on 7.0.
@implementation UIDynamicBehavior {
    // Not retained and not weak, as 7.0's: a weak reference reads nil while the animator deallocates, and its
    // -dealloc dissociates every registered behavior, which needs the animator's world. Every path that ends an
    // animator's hold on a behavior clears it (_unregisterBehavior:, removeAllBehaviors, -[UIDynamicAnimator dealloc]).
    __unsafe_unretained UIDynamicAnimator *_context;
    NSMutableArray *_items;
    NSMutableArray *_behaviors;
    NSMutableArray *_addedBehaviors;
    BOOL _isPrimitiveBehavior;
    BOOL _associated;
    void (^_action)(void);
}

- (instancetype)init
{
    return [self charon_initPrimitive:NO];
}

- (instancetype)charon_initPrimitive:(BOOL)primitive __attribute__((objc_method_family(init)))
{
    if (!(self = [super init]))
        return nil;
    _isPrimitiveBehavior = primitive;
    if (primitive) {
        _items = [NSMutableArray new];
    } else {
        _addedBehaviors = [NSMutableArray new];
        _behaviors = [NSMutableArray new];
    }
    return self;
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithString:[super description]];
    if ([self charon_allowsAnimatorToStop])
        [description appendString:@" (Stoppable)"];
    if (_action)
        [description appendString:@" (A)"];
    return description;
}

- (NSMutableArray *)charon_items
{
    return _items;
}

- (NSArray *)childBehaviors
{
    return [NSArray arrayWithArray:_behaviors];
}

- (UIDynamicAnimator *)dynamicAnimator
{
    return _context;
}

- (UIDynamicAnimator *)charon_context
{
    return _context;
}

- (void)charon_setContext:(UIDynamicAnimator *)animator
{
    _context = animator;
}

- (void (^)(void))action
{
    return _action;
}

- (void)setAction:(void (^)(void))action
{
    _action = [action copy];
}

- (void)addChildBehavior:(UIDynamicBehavior *)behavior
{
    if (!_behaviors || [_behaviors containsObject:behavior])
        return;
    UIDynamicAnimator *context = _context;
    if (context) {
        [context charon_checkBehavior:behavior];
        [context charon_registerBehavior:behavior];
    } else {
        [_addedBehaviors addObject:behavior];
    }
    [_behaviors addObject:behavior];
}

- (void)removeChildBehavior:(UIDynamicBehavior *)behavior
{
    if (![_behaviors containsObject:behavior])
        return;
    UIDynamicAnimator *context = _context;
    if (context)
        [context charon_unregisterBehavior:behavior];
    else
        [_addedBehaviors removeObject:behavior];
    [_behaviors removeObject:behavior];
}

- (void)willMoveToAnimator:(UIDynamicAnimator *)animator
{
}

- (BOOL)charon_isAssociated
{
    return _associated;
}

- (void)charon_associate
{
    _associated = YES;
    UIDynamicAnimator *context = _context;
    for (UIDynamicBehavior *behavior in [_addedBehaviors copy]) {
        [context charon_checkBehavior:behavior];
        [context charon_registerBehavior:behavior];
    }
    [_addedBehaviors removeAllObjects];
}

- (void)charon_dissociate
{
    _associated = NO;
    [_addedBehaviors addObjectsFromArray:_behaviors];
    UIDynamicAnimator *context = _context;
    for (UIDynamicBehavior *behavior in [_behaviors copy])
        [context charon_unregisterBehavior:behavior];
}

- (void)charon_step
{
}

- (void)charon_reevaluate:(NSInteger)mode
{
}

// A primitive behavior keeps the animator running; a composite one lets it stop when it has no action,
// or when every child lets it stop (the action of a parent with children is not asked).
- (BOOL)charon_allowsAnimatorToStop
{
    if (_isPrimitiveBehavior)
        return NO;
    if (_behaviors.count == 0)
        return _action == nil;
    for (UIDynamicBehavior *behavior in _behaviors) {
        if (![behavior charon_allowsAnimatorToStop])
            return NO;
    }
    return YES;
}

- (void)charon_changedParameterForBody:(CharonDynamicsBody *)body
{
    body.resting = NO;
    [_context charon_tickle];
}

@end
