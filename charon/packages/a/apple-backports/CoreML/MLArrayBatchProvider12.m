/* MLArrayBatchProvider, in a file of its own because an object may only carry the API of a single
 * release: the batch provider arrived in iOS 12 and the dictionary provider beside it in iOS 11.
 * Both conform to the protocol this package defines in MLFeatureProvider.m, which has to be there
 * for the same reason -- a protocol is a definition, and a definition cannot come from a header
 * the compiler has already read.
 *
 * A batch is a provider of providers, so a model asked for a batch of predictions is asked for one
 * prediction per element of an array. The class is thin on purpose: it holds what it was given and
 * answers it by index, and the work of deciding whether a value is allowed is the feature
 * description's, which is where the model's own rules are.
 */
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

/* A dictionary of names to arrays is the other shape a batch arrives in: one array per feature,
 * each of the same length, which is the form a caller has when its inputs came out of a table
 * or a file of columns. The providers are then built by index across the arrays, so element
 * zero of every array is the first input and the names stay the names. The arrays have to be of
 * one length, because a batch of inputs that is not a rectangle is not a batch, and a caller
 * that is refused here is told which name is short rather than being answered a prediction for
 * an input that was never complete. */
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
            /* Core ML counts the values of every feature without asking what they are, and a
             * feature whose values are not a list raises there. The port raises too, and with the
             * name in the reason: a caller that catches an exception catches something either way,
             * and a nil here would be an answer Core ML does not give. */
            [NSException raise:NSInvalidArgumentException
                        format:@"the values of '%@' are a %@, and a batch needs a list of them", name,
                               NSStringFromClass([dictionary[name] class])];
        }
        if (count == 0) {
            count = [dictionary[name] count];
        } else if ([dictionary[name] count] != count) {
            /* The framework-level code: the batch is malformed rather than a feature of the wrong
             * type, and MLModelError has no case of its own for that -- measured against a real
             * Core ML, which answers 0 here. */
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
    /* An index outside the array raises, as indexing an NSArray does, which is what Core ML's own
     * provider does -- it is one statement over the array and nothing else. Answering nil instead
     * would be a difference an application can tell: a caller that indexes past the end on a
     * release with Core ML gets an NSRangeException, and one that got nil here would go on to read
     * a feature of a provider that is not there. */
    return _array[(NSUInteger)index];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLArrayBatchProvider %lu providers>", (unsigned long)_array.count];
}

@end
