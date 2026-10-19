#import <CoreML/CoreML.h>

#import <objc/runtime.h>
#import <stdarg.h>
#import <string.h>

#import "check.h"
#import "coreml-models.h"

@interface MLModelAsset (CharonEighteen)
+ (instancetype)modelAssetWithSpecificationData:(NSData *)specificationData
                                    blobMapping:(NSDictionary<NSURL *, NSData *> *)blobMapping
                                          error:(NSError **)error;
- (void)functionNamesWithCompletionHandler:(void (^)(NSArray<NSString *> *, NSError *))handler;
- (void)modelDescriptionWithCompletionHandler:(void (^)(MLModelDescription *, NSError *))handler;
- (void)modelDescriptionOfFunctionNamed:(NSString *)functionName
                      completionHandler:(void (^)(MLModelDescription *, NSError *))handler;
@end

@interface MLModel (CharonSeventeen)
- (void)predictionFromFeatures:(id<MLFeatureProvider>)input
             completionHandler:(void (^)(id<MLFeatureProvider>, NSError *))handler;
- (void)predictionFromFeatures:(id<MLFeatureProvider>)input
                      options:(MLPredictionOptions *)options
            completionHandler:(void (^)(id<MLFeatureProvider>, NSError *))handler;
@end

static void coreml_check(BOOL passed, const char *name, NSString *detail)
{
    charon_check(passed, name, detail);
    if (!passed) {
        fprintf(stderr, "FAIL %s: %s\n", name, detail.UTF8String);
    }
}

#undef CHECK
#undef CHECK_EQUAL
#define CHECK(condition, name) coreml_check((condition) ? YES : NO, name, @#condition)
#define CHECK_EQUAL(actual, expected, name) do { \
        id charon_actual = (actual), charon_expected = (expected); \
        coreml_check(charon_actual == charon_expected || [charon_actual isEqual:charon_expected], name, \
                     [NSString stringWithFormat:@"%@ != %@", charon_actual, charon_expected]); \
    } while (0)

static MLModel *model_from(NSString *label, const unsigned char *bytes, unsigned long length, NSError **error)
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                                 [NSString stringWithFormat:@"charon-coreml-%@.mlmodel", label]];
    NSData *container = [NSData dataWithBytes:bytes length:length];
    if (![container writeToFile:path atomically:YES]) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
        return nil;
    }
    return [MLModel modelWithContentsOfURL:[NSURL fileURLWithPath:path] error:error];
}

static void charon_label(char *into, size_t size, NSString *format, ...)
{
    va_list arguments;
    NSString *text;
    va_start(arguments, format);
    text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    strncpy(into, text.UTF8String, size - 1);
    into[size - 1] = 0;
}

static MLFeatureValue *value_for(MLFeatureDescription *described)
{
    if (described.type == MLFeatureTypeInt64) {
        return [MLFeatureValue featureValueWithInt64:3];
    }
    if (described.type == MLFeatureTypeDouble) {
        return [MLFeatureValue featureValueWithDouble:0.5];
    }
    if (described.type == MLFeatureTypeString) {
        return [MLFeatureValue featureValueWithString:@"a string value"];
    }
    if (described.type == MLFeatureTypeMultiArray) {
        MLMultiArrayConstraint *constraint = described.multiArrayConstraint;
        NSError *failure = nil;
        MLMultiArray *array = [[MLMultiArray alloc] initWithShape:constraint.shape
                                                          dataType:constraint.dataType
                                                             error:&failure];
        NSInteger element;
        if (array == nil) {
            return nil;
        }
        for (element = 0; element < array.count; element++) {
            [array setObject:@((double)((element % 5) - 2) * 0.25) atIndexedSubscript:element];
        }
        return [MLFeatureValue featureValueWithMultiArray:array];
    }
    return nil;
}

static void check_value_types(void)
{
    MLFeatureValue *int64 = [MLFeatureValue featureValueWithInt64:7];
    MLFeatureValue *real = [MLFeatureValue featureValueWithDouble:1.5];
    MLFeatureValue *text = [MLFeatureValue featureValueWithString:@"abc"];
    MLFeatureValue *undefined = [MLFeatureValue undefinedFeatureValueWithType:MLFeatureTypeDouble];
    MLSequence *sequence = [MLSequence sequenceWithInt64Array:@[ @1, @2 ]];
    MLFeatureValue *values = [MLFeatureValue featureValueWithSequence:sequence];

    CHECK_EQUAL(@(MLFeatureTypeInt64), @(int64.type), "featureValueWithInt64 is of the int64 type");
    CHECK_EQUAL(@(MLFeatureTypeDouble), @(real.type), "featureValueWithDouble is of the double type");
    CHECK_EQUAL(@(MLFeatureTypeString), @(text.type), "featureValueWithString is of the string type");
    CHECK_EQUAL(@(MLFeatureTypeSequence), @(values.type), "a sequence value is of the sequence type");
    CHECK_EQUAL(@7, @(int64.int64Value), "an int64 value answers its own number");
    CHECK_EQUAL(@1.5, @(real.doubleValue), "a double value answers its own number");
    CHECK_EQUAL(@"abc", text.stringValue, "a string value answers its own string");
    CHECK(int64.doubleValue == 0.0, "a double read out of an int64 value is zero");
    CHECK(real.int64Value == 0, "an int64 read out of a double value is zero");
    CHECK(int64.stringValue == nil, "a string read out of a number is nil");
    CHECK(text.multiArrayValue == nil, "an array read out of a string is nil");
    CHECK(real.dictionaryValue == nil, "a dictionary read out of a number is nil");
    CHECK_EQUAL(@(MLFeatureTypeDouble), @(undefined.type), "an undefined value keeps the type it was given");
    CHECK(undefined.isUndefined, "an undefined value says so");
    CHECK(!int64.isUndefined, "a value that holds something does not");
    {
        MLSequence *two = [MLSequence sequenceWithInt64Array:@[ @1, @2 ]];
        MLSequence *words = [MLSequence sequenceWithStringArray:@[ @"a", @"b" ]];
        CHECK_EQUAL(@(2ul), @(two.int64Values.count), "a sequence keeps its elements");
        CHECK_EQUAL(@"b", [words stringValues][1], "a string sequence keeps its strings");
    }
    CHECK(sequence.type == MLFeatureTypeInt64, "a sequence of numbers is of the int64 element type");
    CHECK([MLFeatureValue featureValueWithInt64:3] != nil, "featureValueWithInt64 builds");
    CHECK([MLFeatureValue featureValueWithSequence:nil] == nil, "a sequence of nil builds nothing");
    CHECK([int64 isEqualToFeatureValue:[MLFeatureValue featureValueWithInt64:7]], "two equal numbers are equal values");
    CHECK(![int64 isEqualToFeatureValue:real], "a number and a real are not equal values");
    CHECK([[int64 copy] isEqualToFeatureValue:int64], "a copy is equal to what it was copied from");
    CHECK_EQUAL(int64.stringValue, [[int64 copy] stringValue], "a copy answers the same");
    CHECK([MLFeatureValue featureValueWithDictionary:@{ @"k" : @1.5 } error:NULL] != nil, "a dictionary value builds");
    CHECK([[MLFeatureValue featureValueWithDictionary:@{ @"k" : @1.5 } error:NULL] dictionaryValue].count == 1,
          "a dictionary value keeps its pair");
}

static void check_arrays(void)
{
    NSError *failure = nil;
    NSArray *two_by_three = @[ @2, @3 ];
    MLMultiArray *array = [[MLMultiArray alloc] initWithShape:two_by_three
                                                     dataType:MLMultiArrayDataTypeFloat32
                                                        error:&failure];
    MLMultiArray *read;
    CHECK(array != nil, "a multi array of a shape builds");
    CHECK_EQUAL(@(6), @(array.count), "a 2 by 3 array holds six elements");
    CHECK_EQUAL(@(MLMultiArrayDataTypeFloat32), @(array.dataType),
                "it is of the element type it was asked for");
    [array setObject:@1.5 atIndexedSubscript:4];
    CHECK_EQUAL(@1.5, [array objectAtIndexedSubscript:4], "an element written is an element read");
    {
        NSArray *position = @[ @1, @1 ];
        CHECK_EQUAL(@1.5, [array objectForKeyedSubscript:position], "the same element by position");
    }
    read = [[MLMultiArray alloc] initWithShape:two_by_three dataType:MLMultiArrayDataTypeFloat32 error:&failure];
    [read setObject:@2.5 atIndexedSubscript:4];
    CHECK_EQUAL(@2.5, [read objectAtIndexedSubscript:4], "a second array keeps its own numbers");
    CHECK([array isKindOfClass:[MLMultiArray class]], "a multi array is a multi array");
    {
        __block const void *seen = NULL;
        __block NSInteger size = 0;
        [read getBytesWithHandler:^(const void *bytes, NSInteger length) {
            seen = bytes;
            size = length;
        }];
        CHECK(seen == read.dataPointer, "getBytesWithHandler hands over the array's own buffer");
        CHECK_EQUAL(@(24), @(size), "and its length in bytes: six doubles");
        {
            __block void *mutableSeen = NULL;
            [read getMutableBytesWithHandler:^(void *bytes, NSInteger length, NSArray<NSNumber *> *strides) {
                mutableSeen = bytes;
                ((float *)bytes)[0] = 7.5f;
                CHECK_EQUAL(@(2), @(strides.count), "the mutable handler hands over the strides");
            }];
            CHECK(mutableSeen == seen, "the mutable handler hands over the same buffer");
            CHECK_EQUAL(@7.5, [read objectAtIndexedSubscript:0], "and a write through it is a write to the array");
        }
    }
    {
        MLFeatureValue *value = [MLFeatureValue featureValueWithMultiArray:read];
        [read setObject:@3.5 atIndexedSubscript:0];
        CHECK_EQUAL(@3.5, [value.multiArrayValue objectAtIndexedSubscript:0], "a value is a window on its array");
        CHECK(value.multiArrayValue == value.multiArrayValue, "the array of a value is the same object twice");
    }
    CHECK([[MLSequence emptySequenceWithType:MLFeatureTypeInt64] int64Values] != nil, "an empty sequence builds");
}

static void check_providers(void)
{
    NSError *failure = nil;
    NSDictionary *given = @{ @"a" : @1.5, @"b" : @"two", @"c" : @3 };
    MLDictionaryFeatureProvider *provider =
        [[MLDictionaryFeatureProvider alloc] initWithDictionary:given error:&failure];
    CHECK(provider != nil, "a provider is made from a dictionary");
    CHECK_EQUAL(@(3ul), @(provider.featureNames.count), "it holds a name for each value");
    CHECK_EQUAL(@1.5, @([provider featureValueForName:@"a"].doubleValue), "a value comes back by name");
    CHECK_EQUAL(@"two", [provider featureValueForName:@"b"].stringValue, "a string value comes back by name");
    CHECK_EQUAL(@3, @([provider featureValueForName:@"c"].int64Value), "a whole number comes back as a whole number");
    CHECK_EQUAL(@(MLFeatureTypeInt64), @([provider featureValueForName:@"c"].type), "a whole NSNumber is an int64 value");
    CHECK_EQUAL(@(MLFeatureTypeDouble), @([provider featureValueForName:@"a"].type), "a real NSNumber is a double value");
    CHECK_EQUAL(@([provider featureValueForName:@"a"].doubleValue), @([provider[@"a"] doubleValue]),
                "a keyed subscript is a value by name");
    CHECK([provider featureValueForName:@"nope"] == nil, "a name that is not there answers nil");
    CHECK_EQUAL(@(3ul), @(provider.dictionary.count), "the dictionary behind it holds every value");
    {
        NSUInteger walked = 0;
        for (NSString *name in provider) {
            walked++;
            (void)name;
        }
        CHECK_EQUAL(@(3ul), @(walked), "fast enumeration walks every name");
    }
    CHECK([[MLDictionaryFeatureProvider alloc] initWithDictionary:@{} error:&failure] != nil,
          "a provider of nothing builds");
    {
        NSArray *two = @[ provider, provider ];
        MLArrayBatchProvider *batch = [[MLArrayBatchProvider alloc] initWithFeatureProviderArray:two];
        CHECK_EQUAL(@(2), @(batch.count), "a batch counts its providers");
        CHECK([batch featuresAtIndex:1] == provider, "a provider comes back by index");
        CHECK_EQUAL(@(2ul), @(batch.array.count), "the array behind it holds both");
    }
    {
        NSDictionary *columns = @{ @"x" : @[ @1.0, @2.0 ] };
        MLArrayBatchProvider *batch = [[MLArrayBatchProvider alloc] initWithDictionary:columns
                                                                                 error:&failure];
        CHECK_EQUAL(@(2), @(batch.count), "a batch from a dictionary of arrays has one per element");
        CHECK_EQUAL(@1.0, @([[batch featuresAtIndex:0] featureValueForName:@"x"].doubleValue), "the first is the first");
        CHECK_EQUAL(@2.0, @([[batch featuresAtIndex:1] featureValueForName:@"x"].doubleValue), "the second is the second");
        NSDictionary *ragged = @{ @"x" : @[ @1.0 ], @"y" : @[ @1.0, @2.0 ] };
        CHECK([[MLArrayBatchProvider alloc] initWithDictionary:ragged error:&failure] == nil,
              "a batch whose features are not of one length is refused");
    }
}

static void check_keys(void)
{
    CHECK_EQUAL(@"learningRate", MLParameterKey.learningRate.name, "a parameter key is named for its parameter");
    CHECK(MLParameterKey.learningRate.scope == nil, "a key of the model as a whole has no scope");
    CHECK([MLParameterKey.learningRate isEqual:MLParameterKey.learningRate], "two keys of one name are equal");
    CHECK_EQUAL(@(MLParameterKey.learningRate.hash), @(MLParameterKey.learningRate.hash), "and hash the same");
    CHECK_EQUAL(@"inner", [[MLParameterKey.learningRate scopedTo:@"inner"] scope], "a scoped key carries its scope");
    CHECK_EQUAL(@"learningRate", [[MLParameterKey.learningRate scopedTo:@"inner"] name], "and keeps its name");
    CHECK(![[MLParameterKey.learningRate scopedTo:@"inner"] isEqual:MLParameterKey.learningRate],
          "a scoped key is not the key of the model as a whole");
    CHECK([[MLParameterKey learningRate] copy] != nil, "a key copies");
    CHECK_EQUAL(@"learningRate", [[[MLParameterKey learningRate] copy] name], "and keeps its name");
    CHECK_EQUAL(@"lossValue", MLMetricKey.lossValue.name, "a metric key is named for its metric");
    CHECK_EQUAL(@"epochIndex", MLMetricKey.epochIndex.name, "the second metric key");
    CHECK_EQUAL(@"miniBatchIndex", MLMetricKey.miniBatchIndex.name, "the third metric key");
    CHECK([MLMetricKey.lossValue isKindOfClass:[MLKey class]], "a metric key is a key");
    {
        NSData *archive = nil;
        MLKey *key = MLParameterKey.momentum;
        archive = [NSKeyedArchiver archivedDataWithRootObject:key];
        MLKey *back = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
        CHECK_EQUAL(key.name, back.name, "a key survives an archive");
        CHECK_EQUAL(key.scope, back.scope, "with its scope");
    }
    {
    {
        MLModel *model = model_from(@"copy", charon_ml_model_glm_classifier, sizeof(charon_ml_model_glm_classifier), NULL);
        MLModelDescription *described = model.modelDescription;
        NSDictionary *inputs = described.inputDescriptionsByName;
        NSEnumerator *each = [inputs keyEnumerator];
        NSString *name;
        while ((name = [each nextObject]) != nil) {
            MLFeatureDescription *one = inputs[name];
            MLFeatureDescription *copy = [one copy];
            MLFeatureDescription *again = [copy copy];
            char label[96];
            snprintf(label, sizeof label, "%s: a description copies twice", name.UTF8String);
            coreml_check([copy isEqual:one] && [again isEqual:one] && copy != one && again != copy, label,
                          @"a copy differs, or is the original");
            if (one.type == MLFeatureTypeMultiArray) {
                MLMultiArrayShapeConstraint *constraint = one.multiArrayConstraint.shapeConstraint;
                MLMultiArrayShapeConstraint *copied = [constraint copy];
                snprintf(label, sizeof label, "%s: its shape constraint copies", name.UTF8String);
                coreml_check(copied != nil && copied != constraint && copied.type == constraint.type &&
                                 [copied.sizeRangeForDimension isEqualToArray:constraint.sizeRangeForDimension] &&
                                 [copied.enumeratedShapes isEqualToArray:constraint.enumeratedShapes],
                             label, @"the constraint did not copy, or copied to something else");
            }
        }
    }
    {
        Class constraints[] = {
            [MLMultiArrayShapeConstraint class], [MLImageSize class], [MLImageSizeConstraint class],
            [MLSequenceConstraint class],       [MLMultiArrayConstraint class], [MLImageConstraint class],
            [MLDictionaryConstraint class],     [MLNumericConstraint class],
        };
        const char *names[] = {"the shape constraint", "an image size", "the image size constraint",
                               "the sequence constraint", "the multi array constraint", "the image constraint",
                               "the dictionary constraint", "the numeric constraint"};
        NSUInteger index;
        for (index = 0; index < 8; index++) {
            char label[96];
            snprintf(label, sizeof label, "%s implements -copyWithZone: itself", names[index]);
            coreml_check(class_getInstanceMethod(constraints[index], @selector(copyWithZone:)) != NULL, label,
                          @"nothing in the class implements it, so a description carrying it cannot be copied");
        }
    }
        CHECK([MLNumericConstraint instancesRespondToSelector:@selector(minNumber)],
              "and answers a least value");
        CHECK([MLNumericConstraint instancesRespondToSelector:@selector(maxNumber)], "and a most");
        CHECK([MLNumericConstraint instancesRespondToSelector:@selector(enumeratedNumbers)],
              "and the set of values a model may allow");
    }
}

static void check_configuration(void)
{
    MLModelConfiguration *configuration = [[MLModelConfiguration alloc] init];
    CHECK(configuration != nil, "a configuration builds");
    CHECK_EQUAL(@(MLComputeUnitsAll), @(configuration.computeUnits), "and answers Core ML's own default");
    configuration.computeUnits = MLComputeUnitsCPUOnly;
    CHECK_EQUAL(@(MLComputeUnitsCPUOnly), @(configuration.computeUnits), "and keeps what it was told");
    configuration.allowLowPrecisionAccumulationOnGPU = YES;
    CHECK(configuration.allowLowPrecisionAccumulationOnGPU, "a GPU option is kept");
    configuration.modelDisplayName = @"a name";
    CHECK_EQUAL(@"a name", configuration.modelDisplayName, "a display name is kept");
    configuration.parameters = @{ MLParameterKey.momentum : @0.5 };
    CHECK_EQUAL(@(1ul), @(configuration.parameters.count), "a parameter is kept");
    CHECK_EQUAL(@([[configuration copy] computeUnits]), @(configuration.computeUnits), "a copy keeps the units");
    CHECK([[configuration copy] computeUnits] == configuration.computeUnits &&
              [[[configuration copy] copy] computeUnits] == configuration.computeUnits,
          "and a copy of a copy keeps them");
    {
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:configuration];
        MLModelConfiguration *back = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
        CHECK_EQUAL(@(configuration.computeUnits), @(back.computeUnits), "a configuration survives an archive");
    }
    MLPredictionOptions *options = [[MLPredictionOptions alloc] init];
    CHECK(options != nil, "options build");
    options.usesCPUOnly = YES;
    CHECK(options.usesCPUOnly, "the CPU-only option is kept");
    options.outputBackings = @{ @"out" : [[MLMultiArray alloc] initWithShape:@[ @1 ]
                                                              dataType:MLMultiArrayDataTypeDouble
                                                                 error:NULL] };
    CHECK_EQUAL(@(1ul), @(options.outputBackings.count), "a backing object is kept");
}

static void check_model(const charon_ml_embedded_model *embedded, int index)
{
    NSError *failure = nil;
    MLModel *model = model_from(@(embedded->name), embedded->bytes, embedded->length, &failure);
    MLModelDescription *description;
    NSMutableDictionary *inputs;
    NSEnumerator *names;
    NSString *name;
    char label[64];

    snprintf(label, sizeof label, "%s: loaded", embedded->name);
    charon_check(model != nil, label, failure.localizedDescription ?: @"(no error)");
    if (model == nil) {
        return;
    }
    description = model.modelDescription;
    snprintf(label, sizeof label, "%s: has a description", embedded->name);
    charon_check(description != nil, label, @"(none)");
    CHECK(description.inputDescriptionsByName.count > 0, "the model names its inputs");
    CHECK(description.outputDescriptionsByName.count > 0, "and its outputs");
    CHECK(model.configuration != nil, "a model carries a configuration");
    CHECK_EQUAL(@(NO), @(description.isUpdatable), "a model of the port's own is not updatable");
    CHECK(description.metadata != nil, "the metadata is a dictionary even when it is empty");

    inputs = [NSMutableDictionary dictionary];
    names = [description.inputDescriptionsByName keyEnumerator];
    while ((name = [names nextObject]) != nil) {
        MLFeatureDescription *described = description.inputDescriptionsByName[name];
        MLFeatureValue *value = value_for(described);
        char constraint[80];
        charon_label(constraint, sizeof constraint, @"%s: %@ is described", embedded->name, name);
        charon_check(described.name != nil, constraint, @"(no name)");
        charon_label(constraint, sizeof constraint, @"%s: %@ answers its type", embedded->name, name);
        charon_check(described.type != MLFeatureTypeInvalid, constraint, @"the invalid type");
        charon_label(constraint, sizeof constraint, @"%s: %@ optional is a flag", embedded->name, name);
        charon_check(described.isOptional == NO || described.isOptional == YES, constraint, @"not a flag");
        charon_label(constraint, sizeof constraint, @"%s: %@ copies", embedded->name, name);
        charon_check([[described copy] isEqual:described], constraint, @"a copy differs");
        charon_label(constraint, sizeof constraint, @"%s: %@ survives an archive", embedded->name, name);
        {
            NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:described];
            MLFeatureDescription *back = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
            charon_check([back isEqual:described], constraint, @"an archived description differs");
        }
        if (described.type == MLFeatureTypeMultiArray) {
            MLMultiArrayConstraint *array = described.multiArrayConstraint;
            charon_label(constraint, sizeof constraint, @"%s: %@ has a multi array constraint", embedded->name, name);
            charon_check(array != nil, constraint, @"(none)");
            charon_label(constraint, sizeof constraint, @"%s: %@ is allowed its own value", embedded->name, name);
            charon_check(value == nil || [described isAllowedValue:value], constraint, @"refused its own value");
            charon_label(constraint, sizeof constraint, @"%s: %@ is not allowed a string", embedded->name, name);
            charon_check(![described isAllowedValue:[MLFeatureValue featureValueWithString:@"x"]], constraint,
                         @"allowed a string");
            charon_label(constraint, sizeof constraint, @"%s: %@ is not allowed an undefined value", embedded->name, name);
            charon_check(![described isAllowedValue:[MLFeatureValue undefinedFeatureValueWithType:described.type]],
                         constraint, @"allowed an undefined value");
        }
        if (value != nil) {
            inputs[name] = value;
        }
    }

    {
        MLDictionaryFeatureProvider *provider = [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputs
                                                                                                 error:&failure];
        id<MLFeatureProvider> answer = [model predictionFromFeatures:provider error:&failure];
        char prediction[80];
        snprintf(prediction, sizeof prediction, "%s: predicted", embedded->name);
        charon_check(answer != nil, prediction, failure.localizedDescription ?: @"(no error)");
        if (answer != nil) {
            CHECK(answer.featureNames.count > 0, "the prediction answers at least one feature");
            names = [answer.featureNames objectEnumerator];
            while ((name = [names nextObject]) != nil) {
                MLFeatureValue *value = [answer featureValueForName:name];
                charon_label(prediction, sizeof prediction, @"%s: %@ is answered", embedded->name, name);
                charon_check(value != nil, prediction, @"(nil)");
                if (value == nil) {
                    continue;
                }
                charon_label(prediction, sizeof prediction, @"%s: %@ is not undefined", embedded->name, name);
                charon_check(!value.isUndefined, prediction, @"undefined");
                if (value.multiArrayValue != nil) {
                    MLMultiArray *array = value.multiArrayValue;
                    charon_label(prediction, sizeof prediction, @"%s: %@ has room", embedded->name, name);
                    charon_check(array.count > 0, prediction, @"an empty array");
                    {
                        NSNumber *first = [value.multiArrayValue objectAtIndexedSubscript:0];
                        [array setObject:first atIndexedSubscript:0];
                    }
                }
                if (value.dictionaryValue.count > 0) {
                    charon_label(prediction, sizeof prediction, @"%s: %@ has scores", embedded->name, name);
                    charon_check(value.dictionaryValue.count > 0, prediction, @"none");
                }
            }
            {
                NSError *batchFailure = nil;
                MLArrayBatchProvider *batch = [[MLArrayBatchProvider alloc]
                    initWithFeatureProviderArray:@[ provider, provider ]];
                id<MLBatchProvider> answers = [model predictionsFromBatch:batch error:&batchFailure];
                snprintf(prediction, sizeof prediction, "%s: a batch of two is answered", embedded->name);
                charon_check(answers != nil, prediction, batchFailure.localizedDescription ?: @"(no error)");
                if (answers != nil) {
                    CHECK_EQUAL(@(2), @(answers.count), "a batch of two answers two");
                    CHECK([[answers featuresAtIndex:0] featureValueForName:
                               [answer.featureNames anyObject]] != nil, "each element of a batch is answered");
                }
            }
            {
                MLPredictionOptions *options = [[MLPredictionOptions alloc] init];
                NSError *optionFailure = nil;
                id<MLFeatureProvider> again = [model predictionFromFeatures:provider
                                                                          options:options
                                                                            error:&optionFailure];
                snprintf(prediction, sizeof prediction, "%s: predicted with options", embedded->name);
                charon_check(again != nil, prediction, optionFailure.localizedDescription ?: @"(no error)");
                if (again != nil) {
                    CHECK([again featureValueForName:[answer.featureNames anyObject]] != nil,
                          "the options form answers the same features");
                }
            }
        }
        {
            NSError *parameterFailure = nil;
            id value = [model parameterValueForKey:MLParameterKey.learningRate error:&parameterFailure];
            char refused[80];
            snprintf(refused, sizeof refused, "%s: a parameter it does not have is refused", embedded->name);
            charon_check(value == nil, refused, @"answered a value");
            snprintf(refused, sizeof refused, "%s: and says so", embedded->name);
            charon_check(parameterFailure != nil, refused, @"(no error)");
        }
    }
    if (index == 0) {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block int called = 0;
        [model predictionFromFeatures:[[MLDictionaryFeatureProvider alloc] initWithDictionary:inputs error:NULL]
                    completionHandler:^(id<MLFeatureProvider> answer, NSError *error) {
                        called++;
                        dispatch_semaphore_signal(done);
                    }];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));
        snprintf(label, sizeof label, "predictionFromFeatures:completionHandler: answers once");
        charon_check(called == 1, label, @"answered a different number of times");
    }
}

static void check_assets(void)
{
    NSData *container = [NSData dataWithBytes:charon_ml_model_glm length:sizeof(charon_ml_model_glm)];
    MLModelAsset *asset = [MLModelAsset modelAssetWithSpecificationData:container error:NULL];
    CHECK(asset != nil, "an asset is made from a container's bytes");
    if (asset == nil) {
        return;
    }
    {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block MLModel *loaded = nil;
        [MLModel loadModelAsset:asset
                   configuration:nil
               completionHandler:^(MLModel *model, NSError *error) {
                   loaded = model;
                   dispatch_semaphore_signal(done);
               }];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));
        CHECK(loaded != nil, "a model loads from an asset");
        CHECK(loaded.modelDescription.inputDescriptionsByName.count > 0, "and describes itself");
    }
    {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block NSArray *names = nil;
        [asset functionNamesWithCompletionHandler:^(NSArray<NSString *> *given, NSError *error) {
            names = given;
            dispatch_semaphore_signal(done);
        }];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));
        CHECK(names != nil, "the functions of a model of one entry point answer an empty list");
        CHECK_EQUAL(@(0ul), @(names.count), "which is empty");
    }
    {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block MLModelDescription *described = nil;
        [asset modelDescriptionWithCompletionHandler:^(MLModelDescription *description, NSError *error) {
            described = description;
            dispatch_semaphore_signal(done);
        }];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));
        CHECK(described.inputDescriptionsByName.count > 0, "an asset describes its model");
    }
    {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block NSError *refused = nil;
        [asset modelDescriptionOfFunctionNamed:@"no such function"
                            completionHandler:^(MLModelDescription *description, NSError *error) {
                                refused = error;
                                dispatch_semaphore_signal(done);
                            }];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));
        CHECK(refused != nil, "a function the model does not have is refused");
    }
    CHECK([MLModelAsset modelAssetWithSpecificationData:[NSData data] error:NULL] == nil,
          "an asset of nothing is refused");
    CHECK([MLModelAsset modelAssetWithSpecificationData:container blobMapping:@{ } error:NULL] != nil,
          "a blob mapping of nothing is the same asset");
    CHECK([MLModelAsset modelAssetWithSpecificationData:container
                                             blobMapping:@{ [NSURL fileURLWithPath:@"/w"] : [@"x" dataUsingEncoding:NSUTF8StringEncoding] }
                                                   error:NULL] == nil,
          "a model whose weights are in blobs is refused by name");
}

static void check_loading_failures(void)
{
    NSError *failure = nil;
    CHECK([MLModel modelWithContentsOfURL:nil error:&failure] == nil, "no URL is refused");
    CHECK([MLModel modelWithContentsOfURL:[NSURL fileURLWithPath:@"/nonexistent.mlmodel"] error:&failure] == nil,
          "a file that is not there is refused");
    CHECK(failure != nil, "and says so");
    CHECK([[MLModel class] respondsToSelector:@selector(modelWithContentsOfURL:configuration:error:)],
          "the configured factory is there");
    CHECK_EQUAL(@"com.apple.CoreML", failure.domain, "in Core ML's own error domain");
    {
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-not-a-model.mlmodel"];
        [@"this is not a model" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        CHECK([MLModel modelWithContentsOfURL:[NSURL fileURLWithPath:path] error:&failure] == nil,
              "a file that is not a model is refused");
    }
    {
        NSString *source = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-compile-source.mlmodel"];
        NSData *container = [NSData dataWithBytes:charon_ml_model_glm length:sizeof(charon_ml_model_glm)];
        NSError *compileFailure = nil;
        NSURL *compiled;
        [container writeToFile:source atomically:YES];
        compiled = [MLModel compileModelAtURL:[NSURL fileURLWithPath:source] error:&compileFailure];
        charon_check(compiled != nil, "a model compiles to a bundle", compileFailure.localizedDescription ?: @"(no error)");
        if (compiled != nil) {
            MLModel *back = [MLModel modelWithContentsOfURL:compiled error:&compileFailure];
            charon_check(back != nil, "and a model is read back out of it",
                         compileFailure.localizedDescription ?: @"(no error)");
            CHECK(back.modelDescription.inputDescriptionsByName.count > 0, "with its inputs");
        }
    }
    {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block NSURL *compiled = nil;
        NSString *source = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-compile-async.mlmodel"];
        [[NSData dataWithBytes:charon_ml_model_glm length:sizeof(charon_ml_model_glm)] writeToFile:source atomically:YES];
        [MLModel compileModelAtURL:[NSURL fileURLWithPath:source]
                  completionHandler:^(NSURL *url, NSError *error) {
                      compiled = url;
                      dispatch_semaphore_signal(done);
                  }];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));
        CHECK(compiled != nil, "the asynchronous compile answers a URL");
    }
    {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block MLModel *loaded = nil;
        [MLModel loadContentsOfURL:[NSURL fileURLWithPath:@"/nonexistent.mlmodel"]
                      configuration:nil
                  completionHandler:^(MLModel *model, NSError *error) {
                      loaded = model;
                      (void)error;
                      dispatch_semaphore_signal(done);
                  }];
        dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30ull * NSEC_PER_SEC));
        CHECK(loaded == nil, "the asynchronous load of a file that is not there answers nil");
    }
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        int index;
        charon_log_to(@(argc > 1 ? argv[1] : "/tmp/charon-coreml.log"));
        printf("coreml: the Core ML surface on this device\n");
        check_value_types();
        check_arrays();
        check_providers();
        check_keys();
        check_configuration();
        for (index = 0; charon_ml_embedded_models[index].name != NULL; index++) {
            check_model(&charon_ml_embedded_models[index], index);
        }
        check_assets();
        check_loading_failures();
        fprintf(stderr, "coreml: %d checks, %d failures\n", charon_checks, charon_failures);
        printf("%d checks, %d failures\n", charon_checks, charon_failures);
    }
    return charon_failures == 0 ? 0 : 1;
}
