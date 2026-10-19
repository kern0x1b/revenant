#import "RevenantCallKit.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation CXTransaction {
    NSUUID *_UUID;
    NSMutableArray<CXAction *> *_actions;
}

@dynamic UUID, complete, actions;
@synthesize revenant_provider = _revenant_provider;

- (instancetype)initWithActions:(NSArray<CXAction *> *)actions
{
    if ((self = [super init])) {
        _UUID = [NSUUID UUID];
        _actions = [NSMutableArray array];
        for (CXAction *action in actions)
            [self addAction:action];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithActions:@[]];
}

- (instancetype)initWithAction:(CXAction *)action
{
    return [self initWithActions:action ? @[action] : @[]];
}

- (NSUUID *)UUID
{
    return _UUID;
}

- (BOOL)isComplete
{
    for (CXAction *action in _actions) {
        if (!action.isComplete)
            return NO;
    }
    return YES;
}

- (NSArray<CXAction *> *)actions
{
    return [_actions copy];
}

- (void)addAction:(CXAction *)action
{
    if (!action)
        return;
    action.revenant_transaction = self;
    [_actions addObject:action];
}

- (void)revenant_actionCompleted:(CXAction *)action
{
    (void)action;
    if (!self.isComplete)
        return;
    [_revenant_provider revenant_removeTransaction:self];
}

- (id)copyWithZone:(NSZone *)zone
{
    CXTransaction *copy = [[CXTransaction allocWithZone:zone] initWithActions:@[]];
    copy->_UUID = [_UUID copy];
    for (CXAction *action in _actions)
        [copy->_actions addObject:[action copy]];
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_UUID forKey:@"UUID"];
    [coder encodeObject:[_actions copy] forKey:@"actions"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSUUID *UUID = [coder decodeObjectOfClass:[NSUUID class] forKey:@"UUID"];
    if (!UUID)
        return nil;
    if ((self = [self initWithActions:@[]])) {
        _UUID = UUID;
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [CXAction class], nil];
        for (CXAction *action in [coder decodeObjectOfClasses:classes forKey:@"actions"])
            [self addAction:action];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p UUID=%@ actions=%lu complete=%@>", NSStringFromClass([self class]), self,
                                      _UUID.UUIDString, (unsigned long)_actions.count, self.isComplete ? @"YES" : @"NO"];
}

@end
