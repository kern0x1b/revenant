#import <CoreML/CoreML.h>

#include "RevenantMLBridge.h"
#include "RevenantMLInternal.h"

@implementation MLKey {
    NSString *_name;
    NSString *_scope;
}

- (instancetype)revenant_initWithName:(NSString *)name scope:(NSString *)scope
{
    MLKey *built = [super init];
    if (built != nil) {
        _name = [name copy];
        _scope = [scope copy];
    }
    return built;
}

- (NSString *)name
{
    return _name;
}

- (NSString *)scope
{
    return _scope;
}

- (BOOL)isEqual:(id)object
{
    MLKey *other = [object isKindOfClass:[MLKey class]] ? object : nil;
    if (other == nil) {
        return NO;
    }
    return (other->_scope == _scope || [other->_scope isEqualToString:_scope]) &&
           (other->_name == _name || [other->_name isEqualToString:_name]);
}

- (NSUInteger)hash
{
    return [_name hash] ^ [_scope hash];
}

- (NSString *)description
{
    return _scope != nil ? [NSString stringWithFormat:@"<MLKey %@ of %@>", _name, _scope]
                         : [NSString stringWithFormat:@"<MLKey %@>", _name];
}

- (id)copyWithZone:(NSZone *)zone
{
    MLKey *copy = [[[self class] allocWithZone:zone] revenant_initWithName:self.name scope:self.scope];
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self revenant_initWithName:[coder decodeObjectOfClass:[NSString class] forKey:@"name"]
                               scope:[coder decodeObjectOfClass:[NSString class] forKey:@"scope"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_scope forKey:@"scope"];
}

+ (instancetype)revenant_keyNamed:(NSString *)name
{
    if (name == nil) {
        return nil;
    }
    return [[[self class] alloc] revenant_initWithName:name scope:nil];
}

@end

@implementation MLParameterKey

+ (MLParameterKey *)learningRate
{
    return [self revenant_keyNamed:@"learningRate"];
}

+ (MLParameterKey *)momentum
{
    return [self revenant_keyNamed:@"momentum"];
}

+ (MLParameterKey *)miniBatchSize
{
    return [self revenant_keyNamed:@"miniBatchSize"];
}

+ (MLParameterKey *)beta1
{
    return [self revenant_keyNamed:@"beta1"];
}

+ (MLParameterKey *)beta2
{
    return [self revenant_keyNamed:@"beta2"];
}

+ (MLParameterKey *)eps
{
    return [self revenant_keyNamed:@"eps"];
}

+ (MLParameterKey *)epochs
{
    return [self revenant_keyNamed:@"epochs"];
}

+ (MLParameterKey *)shuffle
{
    return [self revenant_keyNamed:@"shuffle"];
}

+ (MLParameterKey *)seed
{
    return [self revenant_keyNamed:@"seed"];
}

+ (MLParameterKey *)numberOfNeighbors
{
    return [self revenant_keyNamed:@"numberOfNeighbors"];
}

+ (MLParameterKey *)linkedModelFileName
{
    return [self revenant_keyNamed:@"linkedModelFileName"];
}

+ (MLParameterKey *)linkedModelSearchPath
{
    return [self revenant_keyNamed:@"linkedModelSearchPath"];
}

+ (MLParameterKey *)weights
{
    return [self revenant_keyNamed:@"weights"];
}

+ (MLParameterKey *)biases
{
    return [self revenant_keyNamed:@"biases"];
}

- (MLParameterKey *)scopedTo:(NSString *)scope
{
    if (scope == nil) {
        return nil;
    }
    return [[MLParameterKey alloc] revenant_initWithName:self.name scope:scope];
}

@end

@implementation MLMetricKey

+ (MLMetricKey *)lossValue
{
    return [self revenant_keyNamed:@"lossValue"];
}

+ (MLMetricKey *)epochIndex
{
    return [self revenant_keyNamed:@"epochIndex"];
}

+ (MLMetricKey *)miniBatchIndex
{
    return [self revenant_keyNamed:@"miniBatchIndex"];
}

@end

@implementation MLParameterDescription {
    MLParameterKey *_key;
    id _defaultValue;
    MLNumericConstraint *_numericConstraint;
}

- (instancetype)revenant_initWithKey:(MLParameterKey *)key
               defaultValue:(id)defaultValue
          numericConstraint:(MLNumericConstraint *)numericConstraint
{
    MLParameterDescription *built = [super init];
    if (built != nil) {
        _key = key;
        _defaultValue = defaultValue;
        _numericConstraint = numericConstraint;
    }
    return built;
}

- (MLParameterKey *)key
{
    return _key;
}

- (id)defaultValue
{
    return _defaultValue;
}

- (MLNumericConstraint *)numericConstraint
{
    return _numericConstraint;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLParameterDescription %@ = %@>", _key.name, _defaultValue];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _key = [coder decodeObjectOfClass:[MLParameterKey class] forKey:@"key"];
        _defaultValue = [coder decodeObjectOfClass:[NSNumber class] forKey:@"defaultValue"];
        _numericConstraint = [coder decodeObjectOfClass:[MLNumericConstraint class]
                                         forKey:@"numericConstraint"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_key forKey:@"key"];
    [coder encodeObject:_defaultValue forKey:@"defaultValue"];
    [coder encodeObject:_numericConstraint forKey:@"numericConstraint"];
}

@end
