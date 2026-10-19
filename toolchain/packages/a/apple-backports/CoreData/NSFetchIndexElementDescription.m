#import "CharonFetchIndex.h"

static void charon_validate_collation(NSFetchIndexElementType collation, NSPropertyDescription *property)
{
    if (collation != NSFetchIndexElementTypeRTree)
        return;
    if (![property isKindOfClass:[NSAttributeDescription class]])
        [NSException raise:NSInvalidArgumentException format:@"Invalid collation type (rtree indexes can only be created on attributes)."];
    NSAttributeType type = [(NSAttributeDescription *)property attributeType];
    if (type != NSInteger16AttributeType && type != NSInteger32AttributeType && type != NSFloatAttributeType)
        [NSException raise:NSInvalidArgumentException format:@"Invalid collation type (rtree indexes can only be created for floats or integers < 32 bit)."];
}

@implementation NSFetchIndexElementDescription {
    NSPropertyDescription *_property;
    NSString *_propertyName;
    NSFetchIndexElementType _collationType;
    __weak NSFetchIndexDescription *_indexDescription;
    BOOL _ascending;
}

- (instancetype)initWithProperty:(NSPropertyDescription *)property collationType:(NSFetchIndexElementType)collationType
{
    if (!property)
        [NSException raise:NSInvalidArgumentException format:@"Can't create an index element without a property"];
    if (!property.name)
        [NSException raise:NSInvalidArgumentException format:@"Can't create an index element with an unnamed property"];
    if (!charon_index_property_allowed(property))
        [NSException raise:NSInvalidArgumentException format:@"Can't create an index element with non-attribute property"];
    charon_validate_collation(collationType, property);
    self = [super init];
    if (self) {
        _property = property;
        _propertyName = property.name;
        _collationType = collationType;
        _ascending = YES;
    }
    return self;
}

- (NSPropertyDescription *)property
{
    return _property;
}

- (NSString *)propertyName
{
    return _propertyName;
}

- (NSFetchIndexElementType)collationType
{
    return _collationType;
}

- (void)setCollationType:(NSFetchIndexElementType)collationType
{
    [_indexDescription _charon_throwIfNotEditable];
    if (_collationType != collationType) {
        charon_validate_collation(collationType, _property);
        [_indexDescription _charon_validateCollationTypeChangeFrom:_collationType to:collationType];
        _collationType = collationType;
    }
}

- (BOOL)isAscending
{
    return _ascending;
}

- (void)setAscending:(BOOL)ascending
{
    [_indexDescription _charon_throwIfNotEditable];
    _ascending = ascending;
}

- (NSFetchIndexDescription *)indexDescription
{
    return _indexDescription;
}

- (void)_charon_setIndexDescription:(NSFetchIndexDescription *)index
{
    _indexDescription = index;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSFetchIndexElementDescription *copy = [[[self class] allocWithZone:zone] initWithProperty:_property collationType:_collationType];
    copy->_ascending = _ascending;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSFetchIndexElementDescription class]])
        return NO;
    NSFetchIndexElementDescription *other = object;
    return [_propertyName isEqual:other->_propertyName] && _collationType == other->_collationType && _ascending == other->_ascending;
}

- (NSUInteger)hash
{
    return [_propertyName hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<NSFetchIndexElementDescription : (%@ (%@), %d, %@)>", _propertyName, @"modeled property", (int)_collationType, _ascending ? @"ascending" : @"descending"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_propertyName forKey:@"NSPropertyName"];
    [coder encodeInteger:(NSInteger)_collationType forKey:@"NSFetchIndexElementType"];
    [coder encodeObject:_indexDescription forKey:@"NSFetchIndexDescription"];
    [coder encodeBool:_ascending forKey:@"NSAscending"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _propertyName = [coder decodeObjectOfClass:[NSString class] forKey:@"NSPropertyName"];
        _indexDescription = [coder decodeObjectOfClass:[NSFetchIndexDescription class] forKey:@"NSFetchIndexDescription"];
        _collationType = (NSFetchIndexElementType)[coder decodeIntegerForKey:@"NSFetchIndexElementType"];
        _ascending = [coder decodeBoolForKey:@"NSAscending"];
    }
    return self;
}

@end
