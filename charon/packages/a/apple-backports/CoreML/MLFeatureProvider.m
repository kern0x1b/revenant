/* The two Core ML protocols, and the two classes an application hands a model through.
 *
 * A protocol is not only a declaration: a class that conforms to one names a protocol object at
 * run time, and that object has to exist somewhere for `conformsToProtocol:` and
 * `objc_getProtocol` to answer. On a release that has Core ML, Core ML's own dylib carries it.
 * This release has no Core ML at all -- the classes are this port's own -- so the port carries
 * the protocols too, and that is why they are declared here rather than taken from Core ML's
 * header: a protocol the compiler has already seen declared is a *reference* to whatever
 * defines it, and a second declaration beside the first is ignored. Declared first, before
 * Core ML's header is imported, they are definitions, and the ones every other file of this
 * package refers to are these.
 *
 * The two declarations are Core ML's own, from its published headers: MLFeatureProvider is a set
 * of feature names and a lookup by name, MLBatchProvider is a count and a lookup by index.
 * Nothing else may be added to either, because an application that conforms to a protocol this
 * port carries has to be able to implement exactly the methods Core ML declares and no more.
 *
 * Then the classes: a prediction is made from a provider -- something that answers a value for a
 * name -- and the dictionary provider is the ordinary one, an NSDictionary of names to values,
 * which is what almost every caller already has. The batch provider is the same thing for a set
 * of inputs at once, and it is a provider of providers, so a model asked for a batch of
 * predictions is asked for one prediction per element of an array. Both are thin on purpose:
 * they hold what they were given and answer it by name or by index, and the work of deciding
 * whether a value is allowed is the feature description's, which is where the model's own rules
 * are.
 */
#import <Foundation/Foundation.h>

@class MLFeatureValue;

@protocol MLFeatureProvider;

/* Core ML's own headers declare both protocols, and the import below is where they are seen. NEITHER is declared
 * here, and MLBatchProvider was until the registry row that carries it: a declaration is only a reference once the
 * compiler has seen the definition, so a second one is ignored ("duplicate protocol definition of 'X' is ignored
 * [-Wduplicate-protocol]"), and this one was worse than ignored - it gave MLBatchProvider the base <NSObject>
 * where the 16.4 SDK's header gives it none, so this object emitted a definition that DISAGREED with the one
 * the generated CoreMLBackportsProtocols12.0.m emits for the same protocol, and ld64 keeps whichever of two weak
 * definitions comes first on the link line, silently. That is the defect this file already fixed once for
 * MLFeatureProvider, and the row that carried it is what made it apply to MLBatchProvider too.
 *
 * Two objects still define __OBJC_PROTOCOL_$_MLBatchProvider - MLArrayBatchProvider12.o, which conforms to it
 * and therefore carries the metadata object it needs, and the generated protocol source - and that is harmless
 * because both definitions are the SDK's own, byte for byte: measured with `nm -m`, both are
 * `weak private external`, and both come from MLBatchProvider.h. The import stays: CharonMLBridge.h needs the
 * enums (MLFeatureType, MLFeatureTypeInt64) that only this header declares. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wduplicate-protocol"
#import <CoreML/CoreML.h>
#pragma clang diagnostic pop

#include "CharonMLBridge.h"
#include "CharonMLInternal.h"


@implementation MLDictionaryFeatureProvider {
    NSDictionary<NSString *, MLFeatureValue *> *_dictionary;
}

/* One value out of a caller's dictionary, as the value of a feature, and what it is for each kind of
 * object -- all of it measured against a real Core ML, because every one of these is a decision a
 * caller can see:
 *
 *   - a value that already is one is kept as it is;
 *   - an NSNumber is a whole number or a real by its own objCType, so @3 is an Int64 value and @3.0
 *     is a Double value. A model that counts what it is given and one that multiplies it are told
 *     apart by that, and a caller who wrote @3 meant a whole number;
 *   - a string, a multi array and a sequence are values of their own kinds;
 *   - an NSArray is a sequence, not a multi array: a sequence is the list Core ML types an input as
 *     when the model has no shape to give it, and a bare array of numbers has no shape either;
 *   - a dictionary is a dictionary value, whose numbers the interpreter can read;
 *   - anything else -- an NSObject, an NSData, an NSURL, a date -- becomes a value of the invalid
 *     type, and nothing is refused: there is no kind of feature value such an object could be, and
 *     a provider that refused to be made would leave the caller with no way to hand over the rest.
 */
static MLFeatureValue *charon_ml_value_of_object(id object)
{
    if ([object isKindOfClass:[MLFeatureValue class]]) {
        return object;
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        const char *encoded = [(NSNumber *)object objCType];
        if (encoded != NULL && (strcmp(encoded, @encode(float)) == 0 || strcmp(encoded, @encode(double)) == 0)) {
            return [MLFeatureValue featureValueWithDouble:[object doubleValue]];
        }
        return [MLFeatureValue featureValueWithInt64:[object longLongValue]];
    }
    if ([object isKindOfClass:[NSString class]]) {
        return [MLFeatureValue featureValueWithString:object];
    }
    if ([object isKindOfClass:[MLMultiArray class]]) {
        return [MLFeatureValue featureValueWithMultiArray:object];
    }
    if ([object isKindOfClass:[MLSequence class]]) {
        return [MLFeatureValue featureValueWithSequence:object];
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        return [MLFeatureValue featureValueWithDictionary:object error:NULL];
    }
    if ([object isKindOfClass:[NSArray class]]) {
        /* A list of strings is a list of strings; anything else is a list of numbers, and an
         * element that is neither is read as the zero it is not, which is what a list of numbers
         * with something else in it means to a model that multiplies what it is given. */
        NSArray *list = object;
        BOOL strings = list.count > 0;
        NSUInteger index;
        NSMutableArray<NSNumber *> *numbers = [NSMutableArray arrayWithCapacity:list.count];
        for (index = 0; index < list.count; index++) {
            id element = list[index];
            if (![element isKindOfClass:[NSString class]]) {
                strings = NO;
            }
            [numbers addObject:@([element isKindOfClass:[NSNumber class]] ? [element doubleValue] : 0.0)];
        }
        return [MLFeatureValue featureValueWithSequence:strings
                                                            ? [MLSequence sequenceWithStringArray:list]
                                                            : [MLSequence sequenceWithInt64Array:numbers]];
    }
    return [MLFeatureValue charon_featureValueOfInvalidType];
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary error:(NSError **)error
{
    NSMutableDictionary<NSString *, MLFeatureValue *> *converted;
    NSEnumerator *names;
    id name;
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if (dictionary == nil) {
        /* A provider of nothing is a provider: Core ML answers one, with no names and no values,
         * and a caller that passes nil by mistake gets the empty provider rather than a failure it
         * has no way to have meant. */
        _dictionary = @{};
        return self;
    }
    converted = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
    names = [dictionary keyEnumerator];
    while ((name = [names nextObject]) != nil) {
        converted[name] = charon_ml_value_of_object([dictionary objectForKey:name]);
    }
    _dictionary = converted;
    return self;
}

- (NSDictionary<NSString *, MLFeatureValue *> *)dictionary
{
    return _dictionary;
}

- (NSSet<NSString *> *)featureNames
{
    return [NSSet setWithArray:[_dictionary allKeys]];
}

- (MLFeatureValue *)featureValueForName:(NSString *)featureName
{
    return featureName != nil ? _dictionary[featureName] : nil;
}

- (MLFeatureValue *)objectForKeyedSubscript:(NSString *)featureName
{
    return [self featureValueForName:featureName];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLDictionaryFeatureProvider %@>", [_dictionary.allKeys
                                                                          componentsJoinedByString:@", "]];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _dictionary = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class],
                                                                          [NSString class],
                                                                          [MLFeatureValue class], nil]
                                           forKey:@"dictionary"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_dictionary forKey:@"dictionary"];
}

/* Fast enumeration walks the names, in the dictionary's own order, which is the order the values
 * were given in. A caller iterating a provider wants the names -- it asks for each value by the
 * name it is given -- and an unordered set would make the walk of a provider whose order is
 * meaningful come out in an order that is not the model's. */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])buffer
                                    count:(NSUInteger)length
{
    return [_dictionary.allKeys countByEnumeratingWithState:state objects:buffer count:length];
}

@end
