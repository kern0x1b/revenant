#import <Foundation/Foundation.h>

@class MLFeatureValue;

@protocol MLFeatureProvider;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wduplicate-protocol"
#import <CoreML/CoreML.h>
#pragma clang diagnostic pop

#include "CharonMLBridge.h"
#include "CharonMLInternal.h"


@implementation MLDictionaryFeatureProvider {
    NSDictionary<NSString *, MLFeatureValue *> *_dictionary;
}

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

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])buffer
                                    count:(NSUInteger)length
{
    return [_dictionary.allKeys countByEnumeratingWithState:state objects:buffer count:length];
}

@end
