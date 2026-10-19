#import "CharonCallKit.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation CXTransaction {
    NSUUID *_UUID;
    NSMutableArray<CXAction *> *_actions;
}

@dynamic UUID, complete, actions;
@synthesize charon_provider = _charon_provider;

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

// A transaction is complete when every action of it is, which makes a
// transaction with no actions complete from the start - that is what CallKit
// answers for one.
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
    action.charon_transaction = self;
    [_actions addObject:action];
}

// A transaction is done once every action of it is, and the provider is told
// then and not before: an application that answers a call and takes another
// off hold in one transaction sees both changes at once, as CallKit gives
// them.
- (void)charon_actionCompleted:(CXAction *)action
{
    (void)action;
    if (!self.isComplete)
        return;
    [_charon_provider charon_removeTransaction:self];
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
