/* MLKey and the two sets of keys built on it: the parameters a model may be asked about, and the
 * metrics it reports while it is being asked.
 *
 * A key is a name and, for a model made of several parts, the name of the part it belongs to. It
 * has no public initialiser in Core ML -- the framework's own keys are the ones that exist, and
 * an application finds them as the class properties of MLParameterKey and MLMetricKey -- so this
 * carries each of those as what it is: the specification's own name for that parameter, and the
 * same name every time, because a key is compared by identity and an application that builds a
 * key of its own has to get the same object the model answers by.
 *
 * The names are the specification's, not guesses: the parameters of a model are written into its
 * container under exactly these names, which is what lets a model read from a file and a key
 * written by hand in an application meet. The specification's own messages for them are in
 * CharonMLModel.c, where the model's parameters are read, and a parameter whose name is not one
 * of these belongs to a sub-model and is scoped to it by name.
 */
#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLInternal.h"

@implementation MLKey {
    NSString *_name;
    NSString *_scope;
}

/* The one way a key is made here: its own name, and the name of the part of the model it belongs
 * to, which is nil for a key of the model as a whole. The strings are copied because a key is
 * held by a model description for as long as the model is. */
- (instancetype)charon_initWithName:(NSString *)name scope:(NSString *)scope
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

/* Two keys are the same key when they have the same name and the same scope, which is what a key
 * is: a name in a model, and nothing else. A dictionary of parameters is keyed by these, and two
 * keys that were different objects with the same name would make that dictionary miss. */
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
    MLKey *copy = [[[self class] allocWithZone:zone] charon_initWithName:self.name scope:self.scope];
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self charon_initWithName:[coder decodeObjectOfClass:[NSString class] forKey:@"name"]
                               scope:[coder decodeObjectOfClass:[NSString class] forKey:@"scope"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_scope forKey:@"scope"];
}

/* The one factory both sets of keys are built from. It is on MLKey rather than on MLParameterKey
 * because a metric key is a key too: each class property below asks for its own name and gets an
 * object of its own class back.
 *
 * A new object every time, which is what a real Core ML answers -- measured: two reads of
 * MLParameterKey.learningRate are two objects that are equal, not one object. A caller compares keys
 * with isEqual: and hashes them into a dictionary, both of which work by name, and one written to
 * expect identity would be holding an assumption a release does not make. */
+ (instancetype)charon_keyNamed:(NSString *)name
{
    if (name == nil) {
        return nil;
    }
    return [[[self class] alloc] charon_initWithName:name scope:nil];
}

@end

/* The parameter keys, one for each parameter a model may be updated by, named as the
 * specification's own update parameters name them. */
@implementation MLParameterKey

+ (MLParameterKey *)learningRate
{
    return [self charon_keyNamed:@"learningRate"];
}

+ (MLParameterKey *)momentum
{
    return [self charon_keyNamed:@"momentum"];
}

+ (MLParameterKey *)miniBatchSize
{
    return [self charon_keyNamed:@"miniBatchSize"];
}

+ (MLParameterKey *)beta1
{
    return [self charon_keyNamed:@"beta1"];
}

+ (MLParameterKey *)beta2
{
    return [self charon_keyNamed:@"beta2"];
}

+ (MLParameterKey *)eps
{
    return [self charon_keyNamed:@"eps"];
}

+ (MLParameterKey *)epochs
{
    return [self charon_keyNamed:@"epochs"];
}

+ (MLParameterKey *)shuffle
{
    return [self charon_keyNamed:@"shuffle"];
}

+ (MLParameterKey *)seed
{
    return [self charon_keyNamed:@"seed"];
}

+ (MLParameterKey *)numberOfNeighbors
{
    return [self charon_keyNamed:@"numberOfNeighbors"];
}

+ (MLParameterKey *)linkedModelFileName
{
    return [self charon_keyNamed:@"linkedModelFileName"];
}

+ (MLParameterKey *)linkedModelSearchPath
{
    return [self charon_keyNamed:@"linkedModelSearchPath"];
}

+ (MLParameterKey *)weights
{
    return [self charon_keyNamed:@"weights"];
}

+ (MLParameterKey *)biases
{
    return [self charon_keyNamed:@"biases"];
}

/* A key of one named part of a model, which is what a scoped key is: the same parameter of one
 * sub-model of a pipeline rather than of the model as a whole. The scope is a name and not a
 * model, so this cannot fail and asks nothing of the model that does not exist yet. */
- (MLParameterKey *)scopedTo:(NSString *)scope
{
    if (scope == nil) {
        return nil;
    }
    return [[MLParameterKey alloc] charon_initWithName:self.name scope:scope];
}

@end

/* The metric keys: the three numbers an updatable model reports as it trains, named as the
 * specification's own training report names them. */
@implementation MLMetricKey

+ (MLMetricKey *)lossValue
{
    return [self charon_keyNamed:@"lossValue"];
}

+ (MLMetricKey *)epochIndex
{
    return [self charon_keyNamed:@"epochIndex"];
}

+ (MLMetricKey *)miniBatchIndex
{
    return [self charon_keyNamed:@"miniBatchIndex"];
}

@end

/* What one parameter of a model is: its key, the value it has unless it is changed, and the bound
 * the model puts on that value if it puts one. */
@implementation MLParameterDescription {
    MLParameterKey *_key;
    id _defaultValue;
    MLNumericConstraint *_numericConstraint;
}

- (instancetype)charon_initWithKey:(MLParameterKey *)key
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
