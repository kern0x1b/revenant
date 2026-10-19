#import "RevenantDynamics.h"

@implementation UIDynamicBehavior {
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
    return [self revenant_initPrimitive:NO];
}

- (instancetype)revenant_initPrimitive:(BOOL)primitive __attribute__((objc_method_family(init)))
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
    if ([self revenant_allowsAnimatorToStop])
        [description appendString:@" (Stoppable)"];
    if (_action)
        [description appendString:@" (A)"];
    return description;
}

- (NSMutableArray *)revenant_items
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

- (UIDynamicAnimator *)revenant_context
{
    return _context;
}

- (void)revenant_setContext:(UIDynamicAnimator *)animator
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
        [context revenant_checkBehavior:behavior];
        [context revenant_registerBehavior:behavior];
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
        [context revenant_unregisterBehavior:behavior];
    else
        [_addedBehaviors removeObject:behavior];
    [_behaviors removeObject:behavior];
}

- (void)willMoveToAnimator:(UIDynamicAnimator *)animator
{
}

- (BOOL)revenant_isAssociated
{
    return _associated;
}

- (void)revenant_associate
{
    _associated = YES;
    UIDynamicAnimator *context = _context;
    for (UIDynamicBehavior *behavior in [_addedBehaviors copy]) {
        [context revenant_checkBehavior:behavior];
        [context revenant_registerBehavior:behavior];
    }
    [_addedBehaviors removeAllObjects];
}

- (void)revenant_dissociate
{
    _associated = NO;
    [_addedBehaviors addObjectsFromArray:_behaviors];
    UIDynamicAnimator *context = _context;
    for (UIDynamicBehavior *behavior in [_behaviors copy])
        [context revenant_unregisterBehavior:behavior];
}

- (void)revenant_step
{
}

- (void)revenant_reevaluate:(NSInteger)mode
{
}

- (BOOL)revenant_allowsAnimatorToStop
{
    if (_isPrimitiveBehavior)
        return NO;
    if (_behaviors.count == 0)
        return _action == nil;
    for (UIDynamicBehavior *behavior in _behaviors) {
        if (![behavior revenant_allowsAnimatorToStop])
            return NO;
    }
    return YES;
}

- (void)revenant_changedParameterForBody:(RevenantDynamicsBody *)body
{
    body.resting = NO;
    [_context revenant_tickle];
}

@end
