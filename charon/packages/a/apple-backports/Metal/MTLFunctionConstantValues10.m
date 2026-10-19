#import "CharonMetal.h"

@implementation MTLFunctionConstantValues {
    NSMutableDictionary *_byIndex;
    NSMutableDictionary *_byName;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _byIndex = [NSMutableDictionary dictionary];
        _byName = [NSMutableDictionary dictionary];
    }
    return self;
}

static NSNumber *number(const void *value, MTLDataType type)
{
    switch (type) {
    case MTLDataTypeBool: return @(*(const uint8_t *)value != 0 ? 1 : 0);
    case MTLDataTypeInt: return @(*(const int32_t *)value);
    case MTLDataTypeUInt: return @(*(const uint32_t *)value);
    case MTLDataTypeFloat: return @(*(const float *)value);
    default: return nil;
    }
}

- (void)setConstantValue:(const void *)value type:(MTLDataType)type atIndex:(NSUInteger)index
{
    NSNumber *n = number(value, type);
    if (n)
        _byIndex[@(index)] = @{@"type": @(type), @"value": n};
}

- (void)setConstantValues:(const void *)values type:(MTLDataType)type withRange:(NSRange)range
{
    NSUInteger width = type == MTLDataTypeBool ? 1 : 4;
    for (NSUInteger i = 0; i < range.length; i++)
        [self setConstantValue:(const uint8_t *)values + i * width type:type atIndex:range.location + i];
}

- (void)setConstantValue:(const void *)value type:(MTLDataType)type withName:(NSString *)name
{
    NSNumber *n = number(value, type);
    if (n)
        _byName[name] = @{@"type": @(type), @"value": n};
}

- (void)reset
{
    [_byIndex removeAllObjects];
    [_byName removeAllObjects];
}

- (NSDictionary *)valueAtIndex:(NSUInteger)index name:(NSString *)name
{
    return _byIndex[@(index)] ?: _byName[name];
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLFunctionConstantValues *copy = [[MTLFunctionConstantValues alloc] init];
    [copy->_byIndex addEntriesFromDictionary:_byIndex];
    [copy->_byName addEntriesFromDictionary:_byName];
    return copy;
}

@end
