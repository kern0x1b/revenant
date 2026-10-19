#import "CharonFetchIndex.h"

@implementation NSFetchIndexDescription {
    NSString *_name;
    NSArray<NSFetchIndexElementDescription *> *_elements;
    __weak NSEntityDescription *_entity;
    NSPredicate *_partialIndexPredicate;
}

- (void)_charon_check:(NSArray<NSFetchIndexElementDescription *> *)elements
{
    NSFetchIndexElementType first = elements.count ? [elements.firstObject collationType] : NSFetchIndexElementTypeBinary;
    for (NSFetchIndexElementDescription *element in elements) {
        if (element.property && !charon_index_property_allowed(element.property))
            [NSException raise:NSInvalidArgumentException format:@"Unsupported property type for index."];
        if (element.collationType != first)
            [NSException raise:NSInvalidArgumentException format:@"Can't mix and match collation types."];
    }
}

- (instancetype)initWithName:(NSString *)name elements:(NSArray<NSFetchIndexElementDescription *> *)elements
{
    if (!name)
        [NSException raise:NSInvalidArgumentException format:@"Can't create an index with no name"];
    if (elements)
        [self _charon_check:elements];
    self = [super init];
    if (self) {
        _name = name;
        _elements = [elements copy];
        for (NSFetchIndexElementDescription *element in _elements)
            [element _charon_setIndexDescription:self];
    }
    return self;
}

- (void)_charon_throwIfNotEditable
{
    NSEntityDescription *entity = _entity;
    if ([entity respondsToSelector:@selector(_throwIfNotEditable)])
        [entity performSelector:@selector(_throwIfNotEditable)];
}

- (void)_charon_validateCollationTypeChangeFrom:(NSFetchIndexElementType)from to:(NSFetchIndexElementType)to
{
    if (from != to && _elements.count <= 1)
        [NSException raise:NSInvalidArgumentException format:@"Can't change an collation type in a multi-element index"];
}

- (void)_charon_setEntity:(NSEntityDescription *)entity
{
    _entity = entity;
}

- (NSString *)name
{
    return _name;
}

- (void)setName:(NSString *)name
{
    if (!name)
        [NSException raise:NSInvalidArgumentException format:@"Can't set an index name to nil"];
    [self _charon_throwIfNotEditable];
    if (![name isEqual:_name] && _entity) {
        for (NSFetchIndexDescription *other in _entity.indexes)
            if (other != self && [other.name isEqual:name])
                [NSException raise:NSInvalidArgumentException format:@"Entity %@ already has an index with name %@", _entity.name, name];
    }
    _name = name;
}

- (NSArray<NSFetchIndexElementDescription *> *)elements
{
    return _elements;
}

- (void)setElements:(NSArray<NSFetchIndexElementDescription *> *)elements
{
    [self _charon_throwIfNotEditable];
    if (elements)
        [self _charon_check:elements];
    _elements = [elements copy];
}

- (NSEntityDescription *)entity
{
    return _entity;
}

- (NSPredicate *)partialIndexPredicate
{
    return _partialIndexPredicate;
}

- (void)setPartialIndexPredicate:(NSPredicate *)predicate
{
    [self _charon_throwIfNotEditable];
    _partialIndexPredicate = predicate;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMutableArray *elements = [NSMutableArray arrayWithCapacity:_elements.count];
    for (NSFetchIndexElementDescription *element in _elements)
        [elements addObject:[element copy]];
    NSFetchIndexDescription *copy = [[[self class] allocWithZone:zone] initWithName:_name elements:elements];
    copy->_partialIndexPredicate = [_partialIndexPredicate copy];
    copy->_entity = _entity;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSFetchIndexDescription class]])
        return NO;
    NSFetchIndexDescription *other = object;
    return [_name isEqual:other->_name] && (_elements == other->_elements || [_elements isEqual:other->_elements]) && (_partialIndexPredicate == other->_partialIndexPredicate || [_partialIndexPredicate isEqual:other->_partialIndexPredicate]);
}

- (NSUInteger)hash
{
    return [_name hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<NSFetchIndexDescription : (%@:%@, elements: %@, predicate: %@)>", _entity.name, _name, _elements, _partialIndexPredicate];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"NSIndexName"];
    [coder encodeObject:_elements forKey:@"NSIndexElements"];
    [coder encodeObject:_entity forKey:@"NSEntity"];
    [coder encodeObject:_partialIndexPredicate forKey:@"NSPartialIndexPredicate"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"NSIndexName"];
        _elements = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSFetchIndexElementDescription class], nil] forKey:@"NSIndexElements"];
        _entity = [coder decodeObjectOfClass:[NSEntityDescription class] forKey:@"NSEntity"];
        _partialIndexPredicate = [coder decodeObjectOfClass:[NSPredicate class] forKey:@"NSPartialIndexPredicate"];
        for (NSFetchIndexElementDescription *element in _elements)
            [element _charon_setIndexDescription:self];
    }
    return self;
}

@end
