#import <CoreML/CoreML.h>

#include "RevenantMLBridge.h"
#include "RevenantMLInternal.h"
#include "RevenantMLModel.h"
#include "RevenantMLPredict.h"
#include "RevenantMLTensor.h"


@implementation MLModelDescription {
    NSDictionary<NSString *, MLFeatureDescription *> *_inputs;
    NSDictionary<NSString *, MLFeatureDescription *> *_outputs;
    NSDictionary<NSString *, MLFeatureDescription *> *_trainingInputs;
    NSDictionary<MLParameterKey *, MLParameterDescription *> *_parameterDescriptions;
    NSString *_predictedFeatureName;
    NSString *_predictedProbabilitiesName;
    NSDictionary<MLModelMetadataKey, id> *_metadata;
    NSArray<id> *_classLabels;
    BOOL _isUpdatable;
}

- (instancetype)revenant_initWithModel:(const revenant_ml_model *)model
{
    NSMutableDictionary *inputs = [NSMutableDictionary dictionary];
    NSMutableDictionary *outputs = [NSMutableDictionary dictionary];
    NSMutableDictionary *training = [NSMutableDictionary dictionary];
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    size_t index;
    MLModelDescription *built = [super init];
    if (built == nil) {
        return nil;
    }
    for (index = 0; index < model->input_count; index++) {
        MLFeatureDescription *described = [[MLFeatureDescription alloc] revenant_initWithFeature:&model->inputs[index]];
        if (described != nil && model->inputs[index].name != NULL) {
            inputs[@(model->inputs[index].name)] = described;
        }
    }
    for (index = 0; index < model->output_count; index++) {
        MLFeatureDescription *described = [[MLFeatureDescription alloc] revenant_initWithFeature:&model->outputs[index]];
        if (described != nil && model->outputs[index].name != NULL) {
            outputs[@(model->outputs[index].name)] = described;
        }
    }
    for (index = 0; index < model->training_input_count; index++) {
        MLFeatureDescription *described =
            [[MLFeatureDescription alloc] revenant_initWithFeature:&model->training_inputs[index]];
        if (described != nil && model->training_inputs[index].name != NULL) {
            training[@(model->training_inputs[index].name)] = described;
        }
    }
    metadata[MLModelAuthorKey] = model->author != NULL ? @(model->author) : @"";
    metadata[MLModelLicenseKey] = model->license != NULL ? @(model->license) : @"";
    metadata[MLModelDescriptionKey] = model->short_description != NULL ? @(model->short_description) : @"";
    metadata[MLModelVersionStringKey] = model->version != NULL ? @(model->version) : @"";
    {
        NSMutableDictionary *own = [NSMutableDictionary dictionary];
        for (index = 0; index < model->user_defined_count; index++) {
            if (model->user_defined_keys[index] != NULL) {
                own[@(model->user_defined_keys[index])] =
                    model->user_defined_values[index] != NULL ? @(model->user_defined_values[index]) : @"";
            }
        }
        metadata[MLModelCreatorDefinedKey] = own;
    }
    for (index = 0; index < model->parameter_count; index++) {
        const revenant_ml_parameter *parameter = &model->parameters[index];
        MLParameterKey *key;
        id value;
        MLNumericConstraint *constraint;
        if (parameter->key == NULL) {
            continue;
        }
        key = [MLParameterKey revenant_keyNamed:@(parameter->key)];
        if (key == nil) {
            continue;
        }
        value = parameter->type == REVENANT_ML_FEATURE_INT64 ? @((int64_t)parameter->number)
                                                          : @(parameter->number);
        if (parameter->has_range) {
            constraint = [[MLNumericConstraint alloc] revenant_initWithMinNumber:@(parameter->range_min)
                                                              maxNumber:@(parameter->range_max)
                                                     enumeratedNumbers:nil];
        } else {
            constraint = nil;
        }
        parameters[key] = [[MLParameterDescription alloc] revenant_initWithKey:key
                                                         defaultValue:value
                                                    numericConstraint:constraint];
    }
    built->_inputs = inputs;
    built->_outputs = outputs;
    built->_trainingInputs = training;
    built->_metadata = metadata;
    built->_parameterDescriptions = parameters;
    built->_predictedFeatureName = model->predicted_feature_name != NULL
                                      ? @(model->predicted_feature_name)
                                      : nil;
    built->_predictedProbabilitiesName = model->predicted_probabilities_name != NULL
                                            ? @(model->predicted_probabilities_name)
                                            : nil;
    built->_isUpdatable = model->is_updatable != 0;
    if (model->class_label_count > 0) {
        NSMutableArray *labels = [NSMutableArray arrayWithCapacity:model->class_label_count];
        for (index = 0; index < model->class_label_count; index++) {
            NSString *label = model->class_labels[index] != NULL ? @(model->class_labels[index]) : @"";
            [labels addObject:model->class_labels_are_numbers ? @([label longLongValue]) : label];
        }
        built->_classLabels = labels;
    }
    return built;
}

- (instancetype)revenant_initWithFunction:(const revenant_ml_function *)function
{
    MLModelDescription *built = [super init];
    if (built != nil) {
        size_t index;
        NSMutableDictionary *inputs = [NSMutableDictionary dictionary];
        NSMutableDictionary *outputs = [NSMutableDictionary dictionary];
        for (index = 0; index < function->input_count; index++) {
            MLFeatureDescription *described = [[MLFeatureDescription alloc] revenant_initWithFeature:&function->inputs[index]];
            if (described != nil && function->inputs[index].name != NULL) {
                inputs[@(function->inputs[index].name)] = described;
            }
        }
        for (index = 0; index < function->output_count; index++) {
            MLFeatureDescription *described = [[MLFeatureDescription alloc] revenant_initWithFeature:&function->outputs[index]];
            if (described != nil && function->outputs[index].name != NULL) {
                outputs[@(function->outputs[index].name)] = described;
            }
        }
        _inputs = inputs;
        _outputs = outputs;
        _trainingInputs = inputs;
        _metadata = @{};
        _parameterDescriptions = @{};
        _predictedFeatureName = function->predicted_feature_name != NULL
                                    ? @(function->predicted_feature_name)
                                    : nil;
        _predictedProbabilitiesName = function->predicted_probabilities_name != NULL
                                          ? @(function->predicted_probabilities_name)
                                          : nil;
    }
    return built;
}

- (NSDictionary<NSString *, MLFeatureDescription *> *)inputDescriptionsByName
{
    return _inputs;
}

- (NSDictionary<NSString *, MLFeatureDescription *> *)outputDescriptionsByName
{
    return _outputs;
}

- (NSDictionary<NSString *, MLFeatureDescription *> *)trainingInputDescriptionsByName
{
    return _trainingInputs;
}

- (NSDictionary<MLParameterKey *, MLParameterDescription *> *)parameterDescriptionsByKey
{
    return _parameterDescriptions;
}

- (NSString *)predictedFeatureName
{
    return _predictedFeatureName;
}

- (NSString *)predictedProbabilitiesName
{
    return _predictedProbabilitiesName;
}

- (NSDictionary<MLModelMetadataKey, id> *)metadata
{
    return _metadata;
}

- (NSArray<id> *)classLabels
{
    return _classLabels;
}

- (BOOL)isUpdatable
{
    return _isUpdatable;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _inputs = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class],
                                                                          [NSString class],
                                                                          [MLFeatureDescription class], nil]
                                       forKey:@"inputs"];
        _outputs = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class],
                                                                           [NSString class],
                                                                           [MLFeatureDescription class], nil]
                                        forKey:@"outputs"];
        _trainingInputs = _inputs;
        _parameterDescriptions = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class],
                                                                                     [MLParameterKey class],
                                                                                     [MLParameterDescription class], nil]
                                                      forKey:@"parameters"];
        _metadata = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], nil]
                                         forKey:@"metadata"];
        _predictedFeatureName = [coder decodeObjectOfClass:[NSString class] forKey:@"predictedFeatureName"];
        _predictedProbabilitiesName = [coder decodeObjectOfClass:[NSString class]
                                                       forKey:@"predictedProbabilitiesName"];
        _classLabels = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], nil]
                                          forKey:@"classLabels"];
        _isUpdatable = [coder decodeBoolForKey:@"isUpdatable"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_inputs forKey:@"inputs"];
    [coder encodeObject:_outputs forKey:@"outputs"];
    [coder encodeObject:_parameterDescriptions forKey:@"parameters"];
    [coder encodeObject:_metadata forKey:@"metadata"];
    [coder encodeObject:_predictedFeatureName forKey:@"predictedFeatureName"];
    [coder encodeObject:_predictedProbabilitiesName forKey:@"predictedProbabilitiesName"];
    [coder encodeObject:_classLabels forKey:@"classLabels"];
    [coder encodeBool:_isUpdatable forKey:@"isUpdatable"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLModelDescription %lu inputs, %lu outputs%@>",
                                      (unsigned long)_inputs.count, (unsigned long)_outputs.count,
                                      _isUpdatable ? @", updatable" : @""];
}

@end


@implementation MLPredictionOptions {
    BOOL _usesCPUOnly;
    NSDictionary<NSString *, id> *_outputBackings;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _usesCPUOnly = NO;
        _outputBackings = @{};
    }
    return self;
}

- (BOOL)usesCPUOnly
{
    return _usesCPUOnly;
}

- (void)setUsesCPUOnly:(BOOL)usesCPUOnly
{
    _usesCPUOnly = usesCPUOnly;
}

- (NSDictionary<NSString *, id> *)outputBackings
{
    return _outputBackings;
}

- (void)setOutputBackings:(NSDictionary<NSString *, id> *)outputBackings
{
    _outputBackings = [outputBackings copy];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLPredictionOptions cpuOnly=%@ backings=%lu>",
                                      _usesCPUOnly ? @"YES" : @"NO", (unsigned long)_outputBackings.count];
}

@end


@implementation MLModelAsset {
    NSData *_specification;
}

+ (instancetype)modelAssetWithSpecificationData:(NSData *)specificationData error:(NSError **)error
{
    MLModelAsset *asset = [[MLModelAsset alloc] init];
    if (asset == nil) {
        return nil;
    }
    if (specificationData.length == 0) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @"there were no specification bytes to make a model of");
        return nil;
    }
    {
        revenant_ml_model probe;
        char message[512];
        if (!revenant_ml_model_read_data(&probe, specificationData.bytes, specificationData.length, message,
                                       sizeof message)) {
            revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @(message));
            return nil;
        }
        revenant_ml_model_release(&probe);
    }
    asset->_specification = [specificationData copy];
    return asset;
}

+ (instancetype)modelAssetWithSpecificationData:(NSData *)specificationData
                                    blobMapping:(NSDictionary<NSURL *, NSData *> *)blobMapping
                                          error:(NSError **)error
{
    if (blobMapping.count == 0) {
        return [self modelAssetWithSpecificationData:specificationData error:error];
    }
    revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                    @"this model keeps its weights in blob files, which are the mlProgram form of a model and "
                    @"are not read by this port; the model is refused rather than run without its weights");
    return nil;
}

+ (instancetype)modelAssetWithURL:(NSURL *)compiledModelURL error:(NSError **)error
{
    NSData *container;
    if (compiledModelURL == nil || !compiledModelURL.isFileURL) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @"a model asset is read from a file's URL");
        return nil;
    }
    {
        BOOL directory = NO;
        NSString *inside = [compiledModelURL.path stringByAppendingPathComponent:@"coremldata.bin"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:inside]) {
            container = [NSData dataWithContentsOfFile:inside];
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:compiledModelURL.path isDirectory:&directory] &&
                   directory) {
            revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"the bundle at %@ holds no coremldata.bin, which is "
                                                       @"where a compiled model keeps its program", compiledModelURL.path]);
            return nil;
        } else {
            container = [NSData dataWithContentsOfFile:compiledModelURL.path];
        }
    }
    if (container.length == 0) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                        [NSString stringWithFormat:@"the model at %@ could not be read", compiledModelURL.path]);
        return nil;
    }
    return [self modelAssetWithSpecificationData:container error:error];
}

- (void)modelDescriptionWithCompletionHandler:(void (^)(MLModelDescription *, NSError *))handler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        MLModelDescription *description = [self descriptionOfFunctionNamed:nil error:&failure];
        if (handler != nil) {
            handler(description, description != nil ? nil : failure);
        }
    });
}

- (void)modelDescriptionOfFunctionNamed:(NSString *)functionName
                      completionHandler:(void (^)(MLModelDescription *, NSError *))handler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        MLModelDescription *description = [self descriptionOfFunctionNamed:functionName error:&failure];
        if (handler != nil) {
            handler(description, description != nil ? nil : failure);
        }
    });
}

- (void)functionNamesWithCompletionHandler:(void (^)(NSArray<NSString *> *, NSError *))handler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        NSArray<NSString *> *names = [self revenant_functionNamesWithError:&failure];
        if (handler != nil) {
            handler(names, names != nil ? nil : failure);
        }
    });
}

- (NSArray<NSString *> *)revenant_functionNamesWithError:(NSError **)error
{
    revenant_ml_model read;
    char message[512];
    NSMutableArray<NSString *> *names;
    size_t index;
    if (!revenant_ml_model_read_data(&read, _specification.bytes, _specification.length, message, sizeof message)) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    names = [NSMutableArray arrayWithCapacity:read.function_count];
    for (index = 0; index < read.function_count; index++) {
        if (read.functions[index].name != NULL) {
            [names addObject:@(read.functions[index].name)];
        }
    }
    revenant_ml_model_release(&read);
    return names;
}

- (MLModelDescription *)descriptionOfFunctionNamed:(NSString *)functionName error:(NSError **)error
{
    revenant_ml_model read;
    char message[512];
    const revenant_ml_function *function = NULL;
    MLModelDescription *description;
    if (!revenant_ml_model_read_data(&read, _specification.bytes, _specification.length, message, sizeof message)) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    if (functionName != nil) {
        function = revenant_ml_model_function_named(&read, [functionName UTF8String]);
        if (function == NULL) {
            NSMutableArray<NSString *> *named = [NSMutableArray array];
            size_t index;
            for (index = 0; index < read.function_count; index++) {
                if (read.functions[index].name != NULL) {
                    [named addObject:@(read.functions[index].name)];
                }
            }
            revenant_ml_model_release(&read);
            revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"this model has no function called '%@'; it has %@",
                                                       functionName, [named componentsJoinedByString:@", "]]);
            return nil;
        }
    }
    description = function != NULL ? [[MLModelDescription alloc] revenant_initWithFunction:function]
                                   : [[MLModelDescription alloc] revenant_initWithModel:&read];
    revenant_ml_model_release(&read);
    return description;
}

- (NSData *)revenant_specificationData
{
    return _specification;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLModelAsset %lu bytes>", (unsigned long)_specification.length];
}

@end


@implementation MLModel {
    revenant_ml_model _model;
    MLModelDescription *_description;
    MLModelConfiguration *_configuration;
    NSURL *_url;
}

- (id<MLFeatureProvider>)predictionFromFeatures:(id<MLFeatureProvider>)input
                                          error:(NSError **)error
{
    revenant_ml_features *inputs = calloc(1, sizeof *inputs);
    revenant_ml_features *outputs = calloc(1, sizeof *outputs);
    NSMutableDictionary<NSString *, MLFeatureValue *> *answered;
    char message[1024];
    NSEnumerator *names;
    id name;
    size_t index;

    if (input == nil || inputs == NULL || outputs == NULL) {
        free(inputs);
        free(outputs);
        revenant_ml_error(error, REVENANT_ML_ERROR_FEATURE_TYPE, @"a prediction needs a provider of values");
        return nil;
    }
    revenant_ml_features_init(inputs);
    revenant_ml_features_init(outputs);
    for (index = 0; index < _model.input_count; index++) {
        const revenant_ml_feature *described = &_model.inputs[index];
        NSString *wanted = described->name != NULL ? @(described->name) : nil;
        MLFeatureValue *value = wanted != nil ? [input featureValueForName:wanted] : nil;
        if (described->optional != 0 || wanted == nil) {
            continue;
        }
        if (value == nil || value.isUndefined) {
            revenant_ml_features_release(inputs);
            revenant_ml_features_release(outputs);
            free(inputs);
            free(outputs);
            revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"Feature %@ is required but not specified.", wanted]);
            return nil;
        }
    }
    names = [input.featureNames objectEnumerator];
    while ((name = [names nextObject]) != nil) {
        MLFeatureValue *value = [input featureValueForName:name];
        revenant_ml_value held;
        if (value == nil || value.isUndefined) {
            continue;
        }
        held = revenant_ml_value_owned_copy([value revenantValue]);
        if (!revenant_ml_features_put(inputs, [name UTF8String], held)) {
            revenant_ml_features_release(inputs);
            free(inputs);
            free(outputs);
            revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"there is no room for a feature named '%@'", name]);
            return nil;
        }
    }
    if (!revenant_ml_predict(&_model, inputs, outputs, message, sizeof message)) {
        revenant_ml_features_release(inputs);
        revenant_ml_features_release(outputs);
        free(inputs);
        free(outputs);
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    revenant_ml_features_release(inputs);
    free(inputs);
    answered = [NSMutableDictionary dictionaryWithCapacity:outputs->count];
    for (index = 0; index < outputs->count; index++) {
        const char *answer_name = outputs->entries[index].name;
        revenant_ml_feature *described = NULL;
        MLFeatureValue *value;
        MLFeatureType type = MLFeatureTypeInvalid;
        for (size_t out = 0; out < _model.output_count; out++) {
            if (answer_name != NULL && _model.outputs[out].name != NULL &&
                strcmp(_model.outputs[out].name, answer_name) == 0) {
                described = &_model.outputs[out];
                break;
            }
        }
        if (described != NULL) {
            type = revenant_ml_feature_type_of(described->type);
        }
        value = [MLFeatureValue revenant_featureValueWithOwned:&outputs->entries[index].value type:type];
        if (value == nil || answer_name == nil) {
            revenant_ml_features_release(outputs);
            revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @"the model's answer had nowhere to go");
            free(outputs);
            return nil;
        }
        answered[@(answer_name)] = value;
    }
    revenant_ml_features_release(outputs);
    free(outputs);
    return [[MLDictionaryFeatureProvider alloc] initWithDictionary:answered error:error];
}

- (id<MLFeatureProvider>)predictionFromFeatures:(id<MLFeatureProvider>)input
                                        options:(MLPredictionOptions *)options
                                          error:(NSError **)error
{
    id<MLFeatureProvider> answer = [self predictionFromFeatures:input error:error];
    if (answer == nil || options == nil || options.outputBackings.count == 0) {
        return answer;
    }
    {
        NSMutableDictionary<NSString *, MLFeatureValue *> *moved = [NSMutableDictionary dictionary];
        NSEnumerator *names = [answer.featureNames objectEnumerator];
        id name;
        while ((name = [names nextObject]) != nil) {
            id backing = options.outputBackings[name];
            MLFeatureValue *value = [answer featureValueForName:name];
            MLMultiArray *wanting = [backing isKindOfClass:[MLMultiArray class]] ? backing : nil;
            MLMultiArray *produced = value.multiArrayValue;
            if (wanting == nil || produced == nil || wanting.count != produced.count ||
                wanting.dataType != produced.dataType) {
                moved[name] = value;
                continue;
            }
            {
                NSUInteger element;
                for (element = 0; element < produced.count; element++) {
                    [wanting setObject:[produced objectAtIndexedSubscript:(NSInteger)element]
                           atIndexedSubscript:(NSInteger)element];
                }
            }
            moved[name] = [MLFeatureValue featureValueWithMultiArray:wanting];
        }
        return [[MLDictionaryFeatureProvider alloc] initWithDictionary:moved error:error];
    }
}

- (void)predictionFromFeatures:(id<MLFeatureProvider>)input
             completionHandler:(void (^)(id<MLFeatureProvider>, NSError *))handler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        id<MLFeatureProvider> answer = [self predictionFromFeatures:input error:&failure];
        if (handler != nil) {
            handler(answer, answer != nil ? nil : failure);
        }
    });
}

- (void)predictionFromFeatures:(id<MLFeatureProvider>)input
                      options:(MLPredictionOptions *)options
            completionHandler:(void (^)(id<MLFeatureProvider>, NSError *))handler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        id<MLFeatureProvider> answer = [self predictionFromFeatures:input options:options error:&failure];
        if (handler != nil) {
            handler(answer, answer != nil ? nil : failure);
        }
    });
}

- (id<MLBatchProvider>)predictionsFromBatch:(id<MLBatchProvider>)inputBatch error:(NSError **)error
{
    return [self predictionsFromBatch:inputBatch options:[[MLPredictionOptions alloc] init] error:error];
}

- (id<MLBatchProvider>)predictionsFromBatch:(id<MLBatchProvider>)inputBatch
                                    options:(MLPredictionOptions *)options
                                      error:(NSError **)error
{
    NSMutableArray<id<MLFeatureProvider>> *answers;
    NSInteger index, count;
    if (inputBatch == nil) {
        revenant_ml_error(error, REVENANT_ML_ERROR_FEATURE_TYPE, @"a batch prediction needs a batch");
        return nil;
    }
    count = inputBatch.count;
    answers = [NSMutableArray arrayWithCapacity:(NSUInteger)(count > 0 ? count : 0)];
    for (index = 0; index < count; index++) {
        id<MLFeatureProvider> one = [inputBatch featuresAtIndex:index];
        id<MLFeatureProvider> answer;
        if (one == nil) {
            revenant_ml_error(error, REVENANT_ML_ERROR_FEATURE_TYPE,
                            [NSString stringWithFormat:@"the batch has %ld providers, and there is none at %ld",
                                                       (long)count, (long)index]);
            return nil;
        }
        answer = [self predictionFromFeatures:one options:options error:error];
        if (answer == nil) {
            if (error != NULL && *error != nil) {
                revenant_ml_error(error, [*error code],
                                [NSString stringWithFormat:@"the prediction of element %ld failed: %@",
                                                           (long)index, [*error localizedDescription]]);
            }
            return nil;
        }
        [answers addObject:answer];
    }
    return [[MLArrayBatchProvider alloc] initWithFeatureProviderArray:answers];
}

- (id)parameterValueForKey:(MLParameterKey *)key error:(NSError **)error
{
    size_t index;
    if (key == nil || key.name == nil) {
        revenant_ml_error(error, REVENANT_ML_ERROR_PARAMETERS, @"a parameter is asked for by its key");
        return nil;
    }
    for (index = 0; index < _model.parameter_count; index++) {
        const revenant_ml_parameter *parameter = &_model.parameters[index];
        if (parameter->key == NULL || ![key.name isEqualToString:@(parameter->key)]) {
            continue;
        }
        if (key.scope != nil) {
            revenant_ml_error(error, REVENANT_ML_ERROR_PARAMETERS,
                            [NSString stringWithFormat:@"'%@' is a parameter of the part called '%@', and this "
                                                       @"model has no part of that name", key.name, key.scope]);
            return nil;
        }
        if (parameter->type == REVENANT_ML_FEATURE_INT64) {
            return @((int64_t)parameter->number);
        }
        return @(parameter->number);
    }
    revenant_ml_error(error, REVENANT_ML_ERROR_PARAMETERS,
                    [NSString stringWithFormat:@"this model has no parameter called '%@'", key.name]);
    return nil;
}

- (MLModelDescription *)modelDescription
{
    if (_description == nil) {
        _description = [[MLModelDescription alloc] revenant_initWithModel:&_model];
    }
    return _description;
}

- (MLModelConfiguration *)configuration
{
    return _configuration;
}

- (void)dealloc
{
    revenant_ml_model_release(&_model);
}

#pragma mark - loading

- (instancetype)initWithContentsOfURL:(NSURL *)url
                        configuration:(MLModelConfiguration *)configuration
                                error:(NSError **)error
{
    char message[1024];
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if (url == nil || !url.isFileURL) {
        revenant_ml_error(error, REVENANT_ML_ERROR_IO,
                        @"a model is read from a file, and the URL given is not a file's");
        return nil;
    }
    if (!revenant_ml_model_read(&_model, url.fileSystemRepresentation, message, sizeof message)) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    _url = [url copy];
    _configuration = configuration != nil ? configuration : [[MLModelConfiguration alloc] init];
    return self;
}

+ (instancetype)modelWithContentsOfURL:(NSURL *)url error:(NSError **)error
{
    return [[MLModel alloc] initWithContentsOfURL:url configuration:nil error:error];
}

+ (instancetype)modelWithContentsOfURL:(NSURL *)url
                        configuration:(MLModelConfiguration *)configuration
                                error:(NSError **)error
{
    return [[MLModel alloc] initWithContentsOfURL:url configuration:configuration error:error];
}

+ (void)loadContentsOfURL:(NSURL *)url
            configuration:(MLModelConfiguration *)configuration
        completionHandler:(void (^)(MLModel *, NSError *))handler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        MLModel *model = [self modelWithContentsOfURL:url configuration:configuration error:&failure];
        if (handler != nil) {
            handler(model, model != nil ? nil : failure);
        }
    });
}

+ (void)loadModelAsset:(MLModelAsset *)asset
         configuration:(MLModelConfiguration *)configuration
     completionHandler:(void (^)(MLModel *, NSError *))handler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        MLModel *model = nil;
        if (asset == nil) {
            revenant_ml_error(&failure, REVENANT_ML_ERROR_GENERIC, @"there was no model asset to load");
        } else {
            model = [[MLModel alloc] revenant_initWithContentsOfAsset:asset configuration:configuration error:&failure];
        }
        if (handler != nil) {
            handler(model, model != nil ? nil : failure);
        }
    });
}

- (instancetype)revenant_initWithContentsOfAsset:(MLModelAsset *)asset
                           configuration:(MLModelConfiguration *)configuration
                                   error:(NSError **)error
{
    char message[1024];
    MLModel *built = [super init];
    if (built == nil) {
        return nil;
    }
    if (!revenant_ml_model_read_data(&_model, asset.revenant_specificationData.bytes, asset.revenant_specificationData.length,
                                   message, sizeof message)) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    _configuration = configuration != nil ? configuration : [[MLModelConfiguration alloc] init];
    return built;
}

#pragma mark - compiling

+ (NSURL *)revenant_compiledModelAtURL:(NSURL *)modelURL error:(NSError **)error
{
    NSData *container = [NSData dataWithContentsOfFile:modelURL.path];
    NSString *name;
    NSString *directory;
    NSFileManager *files = [NSFileManager defaultManager];
    if (container.length == 0) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                        [NSString stringWithFormat:@"the model at %@ could not be read", modelURL.path]);
        return nil;
    }
    name = [[[modelURL.path lastPathComponent] stringByDeletingPathExtension]
        stringByAppendingPathExtension:@"mlmodelc"];
    directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                           [@"revenant-coreml-" stringByAppendingString:
                                                         [[NSUUID UUID] UUIDString]]];
    directory = [directory stringByAppendingPathComponent:name];
    if (![files createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL] ||
        ![[container copy] writeToFile:[directory stringByAppendingPathComponent:@"coremldata.bin"]
                           atomically:YES]) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                        [NSString stringWithFormat:@"the bundle at %@ could not be written", directory]);
        return nil;
    }
    return [NSURL fileURLWithPath:directory];
}

+ (NSURL *)compileModelAtURL:(NSURL *)modelURL error:(NSError **)error
{
    if (modelURL == nil || !modelURL.isFileURL) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @"a model is compiled from a file's URL");
        return nil;
    }
    return [self revenant_compiledModelAtURL:modelURL error:error];
}

+ (void)compileModelAtURL:(NSURL *)modelURL
        completionHandler:(void (^)(NSURL *, NSError *))handler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil;
        NSURL *compiled = [self compileModelAtURL:modelURL error:&failure];
        if (handler != nil) {
            handler(compiled, compiled != nil ? nil : failure);
        }
    });
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLModel %@>", _url != nil ? _url.lastPathComponent : @"in memory"];
}

@end
