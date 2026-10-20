#import <Foundation/Foundation.h>

@implementation NSOrderedCollectionChange {
@private
    id _object;
    NSCollectionChangeType _changeType;
    NSUInteger _index;
    NSUInteger _associatedIndex;
}

+ (NSOrderedCollectionChange *)changeWithObject:(id)object type:(NSCollectionChangeType)type index:(NSUInteger)index
{
    return [[self alloc] initWithObject:object type:type index:index associatedIndex:NSNotFound];
}

+ (NSOrderedCollectionChange *)changeWithObject:(id)object type:(NSCollectionChangeType)type index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex
{
    return [[self alloc] initWithObject:object type:type index:index associatedIndex:associatedIndex];
}

- (id)init
{
    [NSException raise:NSInternalInconsistencyException format:@"Unavailable method init called on class NSException"];
    return nil;
}

- (instancetype)initWithObject:(id)object type:(NSCollectionChangeType)type index:(NSUInteger)index
{
    return [self initWithObject:object type:type index:index associatedIndex:NSNotFound];
}

- (instancetype)initWithObject:(id)object type:(NSCollectionChangeType)type index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex
{
    if (type != NSCollectionChangeInsert && type != NSCollectionChangeRemove)
        [[NSException exceptionWithName:NSInvalidArgumentException reason:@"Invalid type for change" userInfo:@{@"type": @(type)}] raise];
    if ((self = [super init])) {
        _object = object;
        _changeType = type;
        _index = index;
        _associatedIndex = associatedIndex;
    }
    return self;
}

- (id)object
{
    return _object;
}

- (NSCollectionChangeType)changeType
{
    return _changeType;
}

- (NSUInteger)index
{
    return _index;
}

- (NSUInteger)associatedIndex
{
    return _associatedIndex;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSOrderedCollectionChange class]])
        return NO;
    NSOrderedCollectionChange *change = other;
    if (_changeType != change.changeType || _index != change.index || _associatedIndex != change.associatedIndex)
        return NO;
    id object = change.object;
    return _object == object || [_object isEqual:object];
}

- (NSUInteger)hash
{
    return [_object hash] ^ (_index * 31) ^ (_associatedIndex * 17) ^ (_changeType ? 0x9e3779b9 : 0);
}

- (NSString *)debugDescription
{
    NSString *kind = _changeType == NSCollectionChangeInsert ? @"insertion" : @"removal";
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p>(%@", NSStringFromClass([self class]), self, kind];
    if (_object)
        [text appendFormat:@" of object <%@: %p>", NSStringFromClass([_object class]), _object];
    [text appendFormat:@" at index %lu", (unsigned long)_index];
    if (_associatedIndex != NSNotFound)
        [text appendFormat:@" associated with index %lu", (unsigned long)_associatedIndex];
    [text appendString:@")"];
    return text;
}

@end
