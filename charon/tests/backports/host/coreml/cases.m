#import <CoreML/CoreML.h>

#import "coreml-cases.h"

static NSString *error_of(NSError *error)
{
    if (error == nil) {
        return @"(no error)";
    }
    return [NSString stringWithFormat:@"%@/%ld", error.domain, (long)error.code];
}

static NSString *numbers(NSArray<NSNumber *> *values)
{
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger index;
    for (index = 0; index < values.count; index++) {
        [parts addObject:[NSString stringWithFormat:@"%ld", (long)values[index].integerValue]];
    }
    return [parts componentsJoinedByString:@","];
}

static NSString *shapes(NSArray<NSArray<NSNumber *> *> *shapes)
{
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger index;
    for (index = 0; index < shapes.count; index++) {
        [parts addObject:numbers(shapes[index])];
    }
    return [parts componentsJoinedByString:@" | "];
}

static NSString *ranges(NSArray<NSValue *> *values)
{
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger index;
    for (index = 0; index < values.count; index++) {
        NSRange range = [values[index] rangeValue];
        [parts addObject:[NSString stringWithFormat:@"%lu+%lu", (unsigned long)range.location,
                                                    (unsigned long)range.length]];
    }
    return [parts componentsJoinedByString:@","];
}

static NSString *sizes(NSArray<MLImageSize *> *values)
{
    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger index;
    for (index = 0; index < values.count; index++) {
        [parts addObject:[NSString stringWithFormat:@"%ldx%ld", (long)values[index].pixelsWide,
                                                     (long)values[index].pixelsHigh]];
    }
    return [parts componentsJoinedByString:@","];
}

static MLFeatureValue *value_for(MLFeatureDescription *described)
{
    switch (described.type) {
    case MLFeatureTypeInt64:
        return [MLFeatureValue featureValueWithInt64:3];
    case MLFeatureTypeDouble:
        return [MLFeatureValue featureValueWithDouble:0.5];
    case MLFeatureTypeString:
        return [MLFeatureValue featureValueWithString:@"a string value"];
    case MLFeatureTypeMultiArray: {
        MLMultiArrayConstraint *constraint = described.multiArrayConstraint;
        NSArray<NSNumber *> *shape = constraint.shape;
        NSError *failure = nil;
        MLMultiArray *array = [[MLMultiArray alloc] initWithShape:shape
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
    default:
        return nil;
    }
}

static void allowed_values(MLFeatureDescription *described, NSString *prefix, CoreMLRecorder record)
{
    NSString *(^name)(NSString *) = ^(NSString *what) {
        return [NSString stringWithFormat:@"allowed/%@/%@", prefix, what];
    };
    MLMultiArrayConstraint *constraint = described.multiArrayConstraint;
    record(name(@"undefined"), [described isAllowedValue:[MLFeatureValue undefinedFeatureValueWithType:described.type]] ? @"YES" : @"NO");
    record(name(@"int64"), [described isAllowedValue:[MLFeatureValue featureValueWithInt64:1]] ? @"YES" : @"NO");
    record(name(@"double"), [described isAllowedValue:[MLFeatureValue featureValueWithDouble:1.0]] ? @"YES" : @"NO");
    record(name(@"string"), [described isAllowedValue:[MLFeatureValue featureValueWithString:@"x"]] ? @"YES" : @"NO");
    if (constraint.shape.count > 0) {
        NSError *failure = nil;
        MLMultiArray *right = [[MLMultiArray alloc] initWithShape:constraint.shape
                                                          dataType:constraint.dataType
                                                             error:&failure];
        MLMultiArray *wrong = [[MLMultiArray alloc]
            initWithShape:@[ @((long long)constraint.shape.firstObject.longLongValue + 1) ]
                 dataType:constraint.dataType
                    error:&failure];
        MLMultiArrayDataType other = constraint.dataType == MLMultiArrayDataTypeFloat32
                                         ? MLMultiArrayDataTypeDouble
                                         : MLMultiArrayDataTypeFloat32;
        MLMultiArray *mistyped = [[MLMultiArray alloc] initWithShape:constraint.shape
                                                             dataType:other
                                                                error:&failure];
        if (right != nil) {
            record(name(@"array-of-the-shape"), [described isAllowedValue:[MLFeatureValue featureValueWithMultiArray:right]] ? @"YES" : @"NO");
        }
        if (wrong != nil) {
            record(name(@"array-of-another-shape"), [described isAllowedValue:[MLFeatureValue featureValueWithMultiArray:wrong]] ? @"YES" : @"NO");
        }
        if (mistyped != nil) {
            record(name(@"array-of-another-type"), [described isAllowedValue:[MLFeatureValue featureValueWithMultiArray:mistyped]] ? @"YES" : @"NO");
        }
    }
}

static MLModel *load_model(NSString *path, NSError **error)
{
#if COREML_HOST
    NSURL *compiled = [MLModel compileModelAtURL:[NSURL fileURLWithPath:path] error:error];
    if (compiled == nil) {
        return nil;
    }
    return [MLModel modelWithContentsOfURL:compiled error:error];
#else
    return [MLModel modelWithContentsOfURL:[NSURL fileURLWithPath:path] error:error];
#endif
}

static void describe(MLFeatureDescription *described, NSString *prefix, CoreMLRecorder record)
{
    MLMultiArrayConstraint *array = described.multiArrayConstraint;
    MLImageConstraint *image = described.imageConstraint;
    MLDictionaryConstraint *dictionary = described.dictionaryConstraint;
    MLSequenceConstraint *sequence = described.sequenceConstraint;
    NSString *(^name)(NSString *) = ^(NSString *what) {
        return [NSString stringWithFormat:@"desc/%@/%@", prefix, what];
    };
    record(name(@"name"), described.name ?: @"(nil)");
    record(name(@"type"), [NSString stringWithFormat:@"%ld", (long)described.type]);
    record(name(@"optional"), described.isOptional ? @"YES" : @"NO");
    record(name(@"multiArrayConstraint"), array != nil ? @"YES" : @"NO");
    record(name(@"imageConstraint"), image != nil ? @"YES" : @"NO");
    record(name(@"dictionaryConstraint"), dictionary != nil ? @"YES" : @"NO");
    record(name(@"sequenceConstraint"), sequence != nil ? @"YES" : @"NO");
    if (array != nil) {
        record(name(@"shape"), numbers(array.shape));
        record(name(@"dataType"), [NSString stringWithFormat:@"%lu", (unsigned long)array.dataType]);
        record(name(@"shapeConstraint"), array.shapeConstraint != nil
                                                ? [NSString stringWithFormat:@"%ld", (long)array.shapeConstraint.type]
                                                : @"(nil)");
        record(name(@"sizeRangeForDimension"), ranges(array.shapeConstraint.sizeRangeForDimension));
        record(name(@"enumeratedShapes"), shapes(array.shapeConstraint.enumeratedShapes));
    }
    if (image != nil) {
        record(name(@"pixelsHigh"), [NSString stringWithFormat:@"%ld", (long)image.pixelsHigh]);
        record(name(@"pixelsWide"), [NSString stringWithFormat:@"%ld", (long)image.pixelsWide]);
        record(name(@"pixelFormatType"), [NSString stringWithFormat:@"%u", (unsigned)image.pixelFormatType]);
        record(name(@"sizeConstraint"), image.sizeConstraint != nil
                                              ? [NSString stringWithFormat:@"%ld", (long)image.sizeConstraint.type]
                                              : @"(nil)");
        record(name(@"pixelsWideRange"), ranges(@[ [NSValue valueWithRange:image.sizeConstraint.pixelsWideRange] ]));
        record(name(@"pixelsHighRange"), ranges(@[ [NSValue valueWithRange:image.sizeConstraint.pixelsHighRange] ]));
        record(name(@"enumeratedImageSizes"), sizes(image.sizeConstraint.enumeratedImageSizes));
    }
    if (dictionary != nil) {
        record(name(@"keyType"), [NSString stringWithFormat:@"%ld", (long)dictionary.keyType]);
    }
    if (sequence != nil) {
        record(name(@"countRange"), ranges(@[ [NSValue valueWithRange:sequence.countRange] ]));
        record(name(@"valueDescription.type"),
               [NSString stringWithFormat:@"%ld", (long)sequence.valueDescription.type]);
    }
    allowed_values(described, prefix, record);
}

static void predict(MLModel *model, NSString *label, CoreMLRecorder record)
{
    NSDictionary<NSString *, MLFeatureDescription *> *inputs = model.modelDescription.inputDescriptionsByName;
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    NSEnumerator *names = [inputs keyEnumerator];
    NSString *name;
    while ((name = [names nextObject]) != nil) {
        MLFeatureValue *value = value_for(inputs[name]);
        if (value != nil) {
            values[name] = value;
        }
    }
    NSError *failure = nil;
    id<MLFeatureProvider> answer = [model predictionFromFeatures:
                                       [[MLDictionaryFeatureProvider alloc] initWithDictionary:values
                                                                                          error:&failure]
                                                            error:&failure];
    if (answer == nil) {
        record([NSString stringWithFormat:@"predict/%@/error", label], failure.localizedDescription ?: @"(none)");
        return;
    }
    record([NSString stringWithFormat:@"predict/%@/names", label],
           [[answer.featureNames allObjects] componentsJoinedByString:@","]);
    NSEnumerator *answered = [answer.featureNames objectEnumerator];
    while ((name = [answered nextObject]) != nil) {
        MLFeatureValue *value = [answer featureValueForName:name];
        MLMultiArray *array = value.multiArrayValue;
        NSDictionary *dictionary = value.dictionaryValue;
        NSString *kind = [NSString stringWithFormat:@"type=%ld", (long)value.type];
        if (array != nil) {
            kind = [kind stringByAppendingFormat:@" shape=%@ count=%ld", numbers(array.shape), (long)array.count];
        }
        if (dictionary.count > 0) {
            NSMutableArray *parts = [NSMutableArray array];
            for (NSString *key in [dictionary.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                [parts addObject:[NSString stringWithFormat:@"%@", key]];
            }
            kind = [kind stringByAppendingString:[@" " stringByAppendingString:[parts componentsJoinedByString:@" "]]];
            for (NSString *key in [dictionary.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                record([NSString stringWithFormat:@"value/%@/%@/%@", label, name, key],
                       [NSString stringWithFormat:@"%.6f", [dictionary[key] doubleValue]]);
            }
        }
        if (value.isUndefined) {
            kind = [kind stringByAppendingString:@" undefined"];
        }
        record([NSString stringWithFormat:@"predict/%@/%@", label, name], kind);
        if (array != nil) {
            NSMutableArray *numbers_read = [NSMutableArray array];
            NSInteger element;
            for (element = 0; element < MIN((NSInteger)array.count, 8); element++) {
                [numbers_read addObject:[NSString stringWithFormat:@"%.4f",
                                                                    [[array objectAtIndexedSubscript:element] doubleValue]]];
            }
            record([NSString stringWithFormat:@"value/%@/%@", label, name],
                   [numbers_read componentsJoinedByString:@","]);
        } else if (value.doubleValue != 0.0) {
            record([NSString stringWithFormat:@"value/%@/%@", label, name],
                   [NSString stringWithFormat:@"%.4f", value.doubleValue]);
        }
    }
}

static void providers(CoreMLRecorder record)
{
    NSError *failure = nil;
    NSDictionary *given = @{ @"a" : @1.5, @"b" : @"two", @"c" : @42 };
    MLDictionaryFeatureProvider *provider = [[MLDictionaryFeatureProvider alloc] initWithDictionary:given
                                                                                            error:&failure];
    record(@"provider/names", [[provider.featureNames allObjects] componentsJoinedByString:@","]);
    record(@"provider/dictionary.count", [NSString stringWithFormat:@"%lu", (unsigned long)provider.dictionary.count]);
    record(@"provider/a.type", [NSString stringWithFormat:@"%ld", (long)[provider featureValueForName:@"a"].type]);
    record(@"provider/a.double", [NSString stringWithFormat:@"%.4f", [provider featureValueForName:@"a"].doubleValue]);
    record(@"provider/b.string", [provider featureValueForName:@"b"].stringValue);
    record(@"provider/c.int64", [NSString stringWithFormat:@"%ld", (long)[provider featureValueForName:@"c"].int64Value]);
    record(@"provider/subscript", [NSString stringWithFormat:@"%.4f", [provider[@"a"] doubleValue]]);
    record(@"provider/missing", [provider featureValueForName:@"nope"] == nil ? @"(nil)" : @"not nil");
    {
        NSMutableArray *walked = [NSMutableArray array];
        for (NSString *name in provider) {
            [walked addObject:name];
        }
        [[walked sortedArrayUsingSelector:@selector(compare:)] description];
        record(@"provider/enumerated.sorted", [walked componentsJoinedByString:@","]);
    }
    {
        MLDictionaryFeatureProvider *refused = [[MLDictionaryFeatureProvider alloc]
            initWithDictionary:@{ @"good" : @1, @"bad" : [[NSObject alloc] init] }
                         error:&failure];
        record(@"provider/refused", refused == nil ? @"nil" : @"not nil");
        record(@"provider/refused.error", error_of(failure));
    }
    {
        MLArrayBatchProvider *batch = [[MLArrayBatchProvider alloc]
            initWithDictionary:@{ @"x" : @[@1.0, @2.0], @"y" : @[@3.0, @4.0] }
                         error:&failure];
        record(@"batch/count", [NSString stringWithFormat:@"%ld", (long)batch.count]);
        record(@"batch/array", [NSString stringWithFormat:@"%lu", (unsigned long)batch.array.count]);
        record(@"batch/0.x", [NSString stringWithFormat:@"%.4f", [[batch featuresAtIndex:0] featureValueForName:@"x"].doubleValue]);
        record(@"batch/1.x", [NSString stringWithFormat:@"%.4f", [[batch featuresAtIndex:1] featureValueForName:@"x"].doubleValue]);
        record(@"batch/1.y", [NSString stringWithFormat:@"%.4f", [[batch featuresAtIndex:1] featureValueForName:@"y"].doubleValue]);
        @try {
            id<MLFeatureProvider> past = [batch featuresAtIndex:9];
            record(@"batch/past-the-end", past == nil ? @"(nil)" : @"not nil");
        } @catch (NSException *raised) {
            record(@"batch/past-the-end", [NSString stringWithFormat:@"%@: %@", raised.name,
                                                                     raised.reason ?: @"(no reason)"]);
        }
    }
    {
        MLArrayBatchProvider *ragged = nil;
        NSString *raised = nil;
        @try {
            ragged = [[MLArrayBatchProvider alloc]
                initWithDictionary:@{ @"x" : @[@1.0, @2.0], @"y" : @[@3.0] }
                             error:&failure];
        } @catch (NSException *exception) {
            raised = [NSString stringWithFormat:@"raised %@", exception.name];
        }
        record(@"batch/ragged", raised ?: (ragged == nil ? @"nil" : @"not nil"));
        record(@"batch/ragged.error", raised ? @"(raised)" : error_of(failure));
    }
}

static void keys(CoreMLRecorder record)
{
    record(@"keys/learningRate.name", MLParameterKey.learningRate.name);
    record(@"keys/learningRate.scope", MLParameterKey.learningRate.scope ?: @"(nil)");
    record(@"keys/learningRate.same", MLParameterKey.learningRate == MLParameterKey.learningRate ? @"YES" : @"NO");
    record(@"keys/epochs.name", MLParameterKey.epochs.name);
    record(@"keys/momentum.name", MLParameterKey.momentum.name);
    record(@"keys/miniBatchSize.name", MLParameterKey.miniBatchSize.name);
    record(@"keys/beta1.name", MLParameterKey.beta1.name);
    record(@"keys/beta2.name", MLParameterKey.beta2.name);
    record(@"keys/eps.name", MLParameterKey.eps.name);
    record(@"keys/shuffle.name", MLParameterKey.shuffle.name);
    record(@"keys/seed.name", MLParameterKey.seed.name);
    record(@"keys/numberOfNeighbors.name", MLParameterKey.numberOfNeighbors.name);
    record(@"keys/linkedModelFileName.name", MLParameterKey.linkedModelFileName.name);
    record(@"keys/linkedModelSearchPath.name", MLParameterKey.linkedModelSearchPath.name);
    record(@"keys/weights.name", MLParameterKey.weights.name);
    record(@"keys/biases.name", MLParameterKey.biases.name);
    record(@"keys/scoped.name", [MLParameterKey.learningRate scopedTo:@"inner"].name);
    record(@"keys/scoped.scope", [MLParameterKey.learningRate scopedTo:@"inner"].scope);
    record(@"keys/scoped.notTheSame", [MLParameterKey.learningRate scopedTo:@"inner"] == MLParameterKey.learningRate
                                                  ? @"YES"
                                                  : @"NO");
    record(@"keys/lossValue.name", MLMetricKey.lossValue.name);
    record(@"keys/epochIndex.name", MLMetricKey.epochIndex.name);
    record(@"keys/miniBatchIndex.name", MLMetricKey.miniBatchIndex.name);
    record(@"keys/lossValue.class", [NSStringFromClass([MLMetricKey.lossValue class]) containsString:@"MLMetricKey"]
                                        ? @"a metric key"
                                        : @"not a metric key");
    record(@"keys/equal", [MLParameterKey.learningRate isEqual:MLParameterKey.learningRate] ? @"YES" : @"NO");
    record(@"keys/equalScoped",
           [MLParameterKey.learningRate isEqual:[MLParameterKey.learningRate scopedTo:@"inner"]] ? @"YES" : @"NO");
}

static void constants(CoreMLRecorder record)
{
    record(@"const/errorDomain", MLModelErrorDomain);
    record(@"const/authorKey", MLModelAuthorKey);
    record(@"const/licenseKey", MLModelLicenseKey);
    record(@"const/descriptionKey", MLModelDescriptionKey);
    record(@"const/versionKey", MLModelVersionStringKey);
    record(@"const/creatorDefinedKey", MLModelCreatorDefinedKey);
    record(@"const/cropRect", MLFeatureValueImageOptionCropRect);
    record(@"const/cropAndScale", MLFeatureValueImageOptionCropAndScale);
    record(@"const/errors", [NSString stringWithFormat:@"%ld,%ld,%ld,%ld,%ld,%ld,%ld",
                                                       (long)MLModelErrorGeneric, (long)MLModelErrorFeatureType,
                                                       (long)MLModelErrorIO, (long)MLModelErrorParameters,
                                                       (long)MLModelErrorUpdate, (long)MLModelErrorModelDecryption,
                                                       (long)MLModelErrorModelCollection]);
    record(@"const/featureTypes", [NSString stringWithFormat:@"%ld,%ld,%ld,%ld,%ld,%ld,%ld",
                                                          (long)MLFeatureTypeInvalid, (long)MLFeatureTypeInt64,
                                                          (long)MLFeatureTypeDouble, (long)MLFeatureTypeString,
                                                          (long)MLFeatureTypeImage, (long)MLFeatureTypeMultiArray,
                                                          (long)MLFeatureTypeDictionary]);
    record(@"const/arrayTypes", [NSString stringWithFormat:@"%lu,%lu,%lu,%lu", (unsigned long)MLMultiArrayDataTypeDouble,
                                                         (unsigned long)MLMultiArrayDataTypeFloat32,
                                                         (unsigned long)MLMultiArrayDataTypeFloat16,
                                                         (unsigned long)MLMultiArrayDataTypeInt32]);
    record(@"const/computeUnits", [NSString stringWithFormat:@"%ld,%ld,%ld", (long)MLComputeUnitsCPUOnly,
                                                           (long)MLComputeUnitsCPUAndGPU, (long)MLComputeUnitsAll]);
    record(@"const/shapeConstraintTypes", [NSString stringWithFormat:@"%ld,%ld,%ld",
                                                                      (long)MLMultiArrayShapeConstraintTypeUnspecified,
                                                                      (long)MLMultiArrayShapeConstraintTypeEnumerated,
                                                                      (long)MLMultiArrayShapeConstraintTypeRange]);
    record(@"const/imageSizeConstraintTypes", [NSString stringWithFormat:@"%ld,%ld,%ld",
                                                                         (long)MLImageSizeConstraintTypeUnspecified,
                                                                         (long)MLImageSizeConstraintTypeEnumerated,
                                                                         (long)MLImageSizeConstraintTypeRange]);
    {
        MLModelConfiguration *configuration = [[MLModelConfiguration alloc] init];
        record(@"config/default.computeUnits", [NSString stringWithFormat:@"%ld", (long)configuration.computeUnits]);
        record(@"config/default.allowLowPrecision", configuration.allowLowPrecisionAccumulationOnGPU ? @"YES" : @"NO");
        record(@"config/default.preferredMetalDevice", configuration.preferredMetalDevice == nil ? @"(nil)" : @"not nil");
        record(@"config/default.parameters", configuration.parameters == nil
                                                    ? @"(nil)"
                                                    : [NSString stringWithFormat:@"%lu",
                                                                         (unsigned long)configuration.parameters.count]);
        record(@"config/default.modelDisplayName", configuration.modelDisplayName ?: @"(nil)");
        configuration.computeUnits = MLComputeUnitsCPUOnly;
        record(@"config/after.computeUnits", [NSString stringWithFormat:@"%ld", (long)configuration.computeUnits]);
        {
            MLModelConfiguration *copied = [configuration copy];
            record(@"config/copy.computeUnits", [NSString stringWithFormat:@"%ld", (long)copied.computeUnits]);
        }
        MLPredictionOptions *options = [[MLPredictionOptions alloc] init];
        record(@"options/default.usesCPUOnly", options.usesCPUOnly ? @"YES" : @"NO");
        record(@"options/default.outputBackings", options.outputBackings == nil
                                                          ? @"(nil)"
                                                          : [NSString stringWithFormat:@"%lu",
                                                                               (unsigned long)options.outputBackings.count]);
    }
}

static void batch_case(MLModel *model, CoreMLRecorder record)
{
    NSMutableArray *providers = [NSMutableArray array];
    NSString *(^names)(id<MLFeatureProvider>) = ^NSString *(id<MLFeatureProvider> provider) {
        return [[provider.featureNames allObjects] componentsJoinedByString:@","];
    };
    NSInteger index;
    NSError *failure = nil;
    id<MLBatchProvider> answers;

    for (index = 0; index < 3; index++) {
        NSDictionary *given = @{ @"x" : @[ @1.0, @2.0, @3.0 ] };
        [providers addObject:[[MLDictionaryFeatureProvider alloc] initWithDictionary:given error:&failure]];
    }
    answers = [model predictionsFromBatch:[[MLArrayBatchProvider alloc] initWithFeatureProviderArray:providers]
                                     error:&failure];
    record(@"batch/answers", answers != nil ? [NSString stringWithFormat:@"%ld", (long)answers.count] : @"(nil)");
    record(@"batch/error", [NSString stringWithFormat:@"%@/%ld", failure.domain ?: @"(none)", (long)failure.code]);
    for (index = 0; index < 3; index++) {
        record([NSString stringWithFormat:@"batch/%ld", (long)index],
               answers != nil ? names([answers featuresAtIndex:index]) : @"(nil)");
    }
}

static void provider_case(CoreMLRecorder record)
{
    NSDictionary *given = @{ @"numbers" : @[ @1, @2, @3 ], @"words" : @[ @"x", @"y" ] };
    NSError *failure = nil;
    MLDictionaryFeatureProvider *provider = [[MLDictionaryFeatureProvider alloc] initWithDictionary:given
                                                                                                error:&failure];
    record(@"provider/numbers.type", [NSString stringWithFormat:@"%ld",
                                                                  (long)[provider featureValueForName:@"numbers"].type]);
    record(@"provider/words.type", [NSString stringWithFormat:@"%ld",
                                                                (long)[provider featureValueForName:@"words"].type]);
    record(@"provider/numbers.sequence",
           [NSString stringWithFormat:@"%@", numbers([provider featureValueForName:@"numbers"].sequenceValue.int64Values)]);
    record(@"provider/words.sequence",
           [NSString stringWithFormat:@"%@", [[provider featureValueForName:@"words"].sequenceValue.stringValues
                                                 componentsJoinedByString:@","]]);
    record(@"provider/array.error", [NSString stringWithFormat:@"%@/%ld", failure.domain ?: @"(none)",
                                                                     (long)failure.code]);
}

static void missing_input(MLModel *model, CoreMLRecorder record)
{
    MLModelDescription *description = model.modelDescription;
    NSString *name = description.inputDescriptionsByName.allKeys.firstObject;
    MLFeatureDescription *described = description.inputDescriptionsByName[name];
    NSError *failure = nil;
    id<MLFeatureProvider> answer;

    if (name == nil || described == nil) {
        return;
    }
    answer = [model predictionFromFeatures:[[MLDictionaryFeatureProvider alloc] initWithDictionary:@{}
                                                                                               error:&failure]
                                    error:&failure];
    record(@"missing/answer", answer != nil ? @"not nil" : @"nil");
    record(@"missing/code", [NSString stringWithFormat:@"%@/%ld", failure.domain ?: @"(none)", (long)failure.code]);
    record(@"missing/names", [failure.localizedDescription rangeOfString:name].location != NSNotFound ? @"named" : @"not named");
    record(@"missing/optional", [NSString stringWithFormat:@"%@", described.isOptional ? @"YES" : @"NO"]);
    record(@"missing/type", [NSString stringWithFormat:@"%ld", (long)described.type]);
}

static void round_trips(CoreMLRecorder record)
{
    NSDictionary *pairs = @{ @"one" : @1.5, @"two" : @2.5 };
    NSArray *shape = @[ @2, @2 ];
    NSArray<NSValue *> *values = @[
        [MLFeatureValue featureValueWithInt64:42],
        [MLFeatureValue featureValueWithDouble:3.5],
        [MLFeatureValue featureValueWithString:@"a string of some length"],
        [MLFeatureValue featureValueWithMultiArray:[[MLMultiArray alloc] initWithShape:shape
                                                                                  dataType:MLMultiArrayDataTypeFloat32
                                                                                     error:NULL]],
        [MLFeatureValue featureValueWithDictionary:pairs error:NULL],
        [MLFeatureValue featureValueWithSequence:[MLSequence sequenceWithInt64Array:@[ @1, @2, @3 ]]],
        [MLFeatureValue undefinedFeatureValueWithType:MLFeatureTypeDouble],
    ];
    NSArray<NSString *> *names = @[ @"int64", @"double", @"string", @"array", @"dictionary", @"sequence",
                                     @"undefined" ];
    NSUInteger index;
    for (index = 0; index < values.count; index++) {
        MLFeatureValue *before = values[index];
        NSData *archive = nil;
        MLFeatureValue *after = nil;
        NSString *key = [NSString stringWithFormat:@"archive/%@", names[index]];
        @try {
            archive = [NSKeyedArchiver archivedDataWithRootObject:before];
            after = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
        } @catch (NSException *raised) {
            NSArray *rest = @[ @"type", @"undefined", @"int64", @"double", @"string", @"array",
                                @"dictionary", @"sequence", @"equal" ];
            NSUInteger each;
            BOOL secure = [raised.reason ?: @"" rangeOfString:@"only supports secure coding"].location != NSNotFound;
            for (each = 0; each < rest.count; each++) {
                record([key stringByAppendingFormat:@"/%@", rest[each]],
                       [NSString stringWithFormat:@"raised %@%@", raised.name,
                                                    secure ? @" (the secure-coding refusal)" : @""]);
            }
            continue;
        }
        record([key stringByAppendingString:@"/type"],
               [NSString stringWithFormat:@"%ld -> %ld", (long)before.type, (long)after.type]);
        record([key stringByAppendingString:@"/undefined"],
               [NSString stringWithFormat:@"%@ -> %@", before.isUndefined ? @"YES" : @"NO",
                                        after.isUndefined ? @"YES" : @"NO"]);
        record([key stringByAppendingString:@"/int64"],
               [NSString stringWithFormat:@"%lld -> %lld", (long long)before.int64Value, (long long)after.int64Value]);
        record([key stringByAppendingString:@"/double"],
               [NSString stringWithFormat:@"%.6f -> %.6f", before.doubleValue, after.doubleValue]);
        record([key stringByAppendingString:@"/string"],
               [NSString stringWithFormat:@"%@ -> %@", before.stringValue ?: @"(nil)", after.stringValue ?: @"(nil)"]);
        record([key stringByAppendingString:@"/array"],
               [NSString stringWithFormat:@"%@ -> %@",
                                        before.multiArrayValue ? numbers(before.multiArrayValue.shape) : @"(nil)",
                                        after.multiArrayValue ? numbers(after.multiArrayValue.shape) : @"(nil)"]);
        record([key stringByAppendingString:@"/dictionary"],
               [NSString stringWithFormat:@"%lu -> %lu", (unsigned long)before.dictionaryValue.count,
                                        (unsigned long)after.dictionaryValue.count]);
        record([key stringByAppendingString:@"/sequence"],
               [NSString stringWithFormat:@"%@ -> %@",
                                        before.sequenceValue ? numbers(before.sequenceValue.int64Values) : @"(nil)",
                                        after.sequenceValue ? numbers(after.sequenceValue.int64Values) : @"(nil)"]);
        record([key stringByAppendingString:@"/equal"],
               [before isEqualToFeatureValue:after] ? @"YES" : @"NO");
    }

    for (index = 0; index < values.count; index++) {
        NSString *key = [NSString stringWithFormat:@"archive/%@/secure", names[index]];
        MLFeatureValue *before = values[index];
        NSData *secure = [NSKeyedArchiver archivedDataWithRootObject:before requiringSecureCoding:YES error:NULL];
        MLFeatureValue *back = secure != nil ? [NSKeyedUnarchiver unarchivedObjectOfClass:[MLFeatureValue class]
                                                                    fromData:secure
                                                                      error:NULL]
                                             : nil;
        record([key stringByAppendingString:@"/type"],
               back == nil ? @"(nil)" : [NSString stringWithFormat:@"%ld", (long)back.type]);
        record([key stringByAppendingString:@"/array"],
               back == nil ? @"(nil)" : (back.multiArrayValue != nil ? numbers(back.multiArrayValue.shape)
                                                                   : @"(nil)"));
        record([key stringByAppendingString:@"/string"],
               back == nil ? @"(nil)" : (back.stringValue ?: @"(nil)"));
        record([key stringByAppendingString:@"/undefined"],
               back == nil ? @"(nil)" : (back.isUndefined ? @"YES" : @"NO"));
        record([key stringByAppendingString:@"/equal"],
               back == nil ? @"(nil)" : ([back isEqualToFeatureValue:before] ? @"YES" : @"NO"));
    }
}

void coreml_run(NSString *models, CoreMLRecorder record)
{
    NSFileManager *files = [NSFileManager defaultManager];
    NSArray *names = [[files contentsOfDirectoryAtPath:models error:NULL]
        sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger index;
    for (index = 0; index < names.count; index++) {
        NSString *file = names[index];
        NSString *label = [file stringByDeletingPathExtension];
        if (![file hasSuffix:@".mlmodel"]) {
            continue;
        }
        NSURL *url = [NSURL fileURLWithPath:[models stringByAppendingPathComponent:file]];
        NSError *failure = nil;
        MLModel *model = load_model(url.path, &failure);
        if (model == nil) {
            record([NSString stringWithFormat:@"model/%@/error", label], error_of(failure));
            continue;
        }
        MLModelDescription *description = model.modelDescription;
        record([NSString stringWithFormat:@"model/%@/inputs", label],
               [[description.inputDescriptionsByName allKeys] componentsJoinedByString:@","]);
        record([NSString stringWithFormat:@"model/%@/outputs", label],
               [[description.outputDescriptionsByName allKeys] componentsJoinedByString:@","]);
        record([NSString stringWithFormat:@"model/%@/predicted", label], description.predictedFeatureName ?: @"(nil)");
        record([NSString stringWithFormat:@"model/%@/probabilities", label],
               description.predictedProbabilitiesName ?: @"(nil)");
        record([NSString stringWithFormat:@"model/%@/updatable", label], description.isUpdatable ? @"YES" : @"NO");
        record([NSString stringWithFormat:@"model/%@/training", label],
               [[description.trainingInputDescriptionsByName allKeys] componentsJoinedByString:@","]);
        {
            NSMutableArray *metadata = [NSMutableArray array];
            for (MLModelMetadataKey key in @[ MLModelAuthorKey, MLModelLicenseKey, MLModelDescriptionKey,
                                              MLModelVersionStringKey ]) {
                [metadata addObject:[NSString stringWithFormat:@"%@=%@", key, description.metadata[key] ?: @"(nil)"]];
            }
            [metadata addObject:[NSString stringWithFormat:@"%@=%@", MLModelCreatorDefinedKey,
                                                          description.metadata[MLModelCreatorDefinedKey] ?: @"(nil)"]];
            record([NSString stringWithFormat:@"model/%@/metadata", label],
                   [metadata componentsJoinedByString:@" "]);
        }
        {
            NSMutableArray *labels = [NSMutableArray array];
            for (id entry in description.classLabels) {
                [labels addObject:[NSString stringWithFormat:@"%@(%@)", entry,
                                                             [entry isKindOfClass:[NSNumber class]] ? @"number" : @"string"]];
            }
            record([NSString stringWithFormat:@"model/%@/classLabels", label], [labels componentsJoinedByString:@","]);
        }
        {
            NSMutableArray *parameters = [NSMutableArray array];
            for (MLParameterKey *key in description.parameterDescriptionsByKey) {
                MLParameterDescription *one = description.parameterDescriptionsByKey[key];
                [parameters addObject:[NSString stringWithFormat:@"%@=%@", key.name, one.defaultValue]];
            }
            record([NSString stringWithFormat:@"model/%@/parameters", label], [parameters componentsJoinedByString:@","]);
        }
        for (NSString *name in description.inputDescriptionsByName) {
            describe(description.inputDescriptionsByName[name],
                     [NSString stringWithFormat:@"%@/input/%@", label, name], record);
        }
        for (NSString *name in description.outputDescriptionsByName) {
            describe(description.outputDescriptionsByName[name],
                     [NSString stringWithFormat:@"%@/output/%@", label, name], record);
        }
        predict(model, label, record);
        if ([label isEqualToString:@"glm_classifier"]) {
            batch_case(model, record);
            missing_input(model, record);
        }
        {
            NSError *missing = nil;
            id value = [model parameterValueForKey:MLParameterKey.learningRate error:&missing];
            record([NSString stringWithFormat:@"model/%@/parameter.learningRate", label],
                   value != nil ? [NSString stringWithFormat:@"%@", value]
                                : [NSString stringWithFormat:@"error %ld", (long)missing.code]);
        }
    }
    {
        NSError *absent = nil;
        MLModel *none = [MLModel modelWithContentsOfURL:[NSURL fileURLWithPath:@"/nonexistent.mlmodel"]
                                                  error:&absent];
        record(@"model/absent", none == nil ? error_of(absent) : @"not nil");
        none = [MLModel modelWithContentsOfURL:[NSURL fileURLWithPath:
                                                    [models stringByAppendingPathComponent:@"manifest.json"]]
                                         error:&absent];
        record(@"model/not-a-model", none == nil ? error_of(absent) : @"not nil");
        none = [MLModel modelWithContentsOfURL:nil error:&absent];
        record(@"model/no-url", none == nil ? error_of(absent) : @"not nil");
    }
    round_trips(record);
    provider_case(record);
    providers(record);
    keys(record);
    constants(record);
    coreml_device_cases(record);
}
