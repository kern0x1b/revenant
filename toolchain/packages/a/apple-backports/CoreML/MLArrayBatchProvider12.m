#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLInternal.h"


@implementation MLArrayBatchProvider {
    NSArray<id<MLFeatureProvider>> *_array;
}

- (instancetype)initWithFeatureProviderArray:(NSArray<id<MLFeatureProvider>> *)array
{
    self = [super init];
    if (self != nil) {
        _array = array != nil ? [array copy] : @[];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, NSArray *> *)dictionary error:(NSError **)error
{
    NSMutableArray<id<MLFeatureProvider>> *providers;
    NSUInteger count = 0, index;
    NSEnumerator *names;
    id name;
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if (dictionary == nil) {
        charon_ml_error(error, CHARON_ML_ERROR_FEATURE_TYPE,
                        @"a batch provider is made from a dictionary, and there was none");
        return nil;
    }
    for (name in dictionary) {
        if (![dictionary[name] isKindOfClass:[NSArray class]]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"the values of '%@' are a %@, and a batch needs a list of them", name,
                               NSStringFromClass([dictionary[name] class])];
        }
        if (count == 0) {
            count = [dictionary[name] count];
        } else if ([dictionary[name] count] != count) {
            charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"the values of '%@' are %lu of %lu, and every "
                                                       @"feature of a batch has to be of one length",
                                                       name, (unsigned long)[dictionary[name] count],
                                                       (unsigned long)count]);
            return nil;
        }
    }
    providers = [NSMutableArray arrayWithCapacity:count];
    for (index = 0; index < count; index++) {
        NSMutableDictionary *one = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
        names = [dictionary keyEnumerator];
        while ((name = [names nextObject]) != nil) {
            one[name] = [dictionary[name] objectAtIndex:index];
        }
        {
            MLDictionaryFeatureProvider *provider =
                [[MLDictionaryFeatureProvider alloc] initWithDictionary:one error:error];
            if (provider == nil) {
                return nil;
            }
            [providers addObject:provider];
        }
    }
    _array = providers;
    return self;
}

- (NSArray<id<MLFeatureProvider>> *)array
{
    return _array;
}

- (NSInteger)count
{
    return (NSInteger)_array.count;
}

- (id<MLFeatureProvider>)featuresAtIndex:(NSInteger)index
{
    return _array[(NSUInteger)index];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLArrayBatchProvider %lu providers>", (unsigned long)_array.count];
}

@end
