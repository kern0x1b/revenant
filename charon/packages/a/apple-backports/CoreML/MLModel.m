/* MLModel and the classes that describe it: what a model is made of, what it takes, and what it
 * answers.
 *
 * A model is a container read once and kept: the C reader builds the whole thing -- its kind, its
 * inputs and outputs, its class labels, its metadata -- and the interpreter runs it over a set
 * of values. This is the surface an application touches: it loads a model from a URL, asks it
 * what it wants through its model description, hands it values through a feature provider, and
 * reads the answer back as another provider.
 *
 * The prediction is the whole of it, and it is three steps with nothing hidden between: the
 * caller's values are copied into the C's own set (the interpreter may consume them, so they
 * cannot be windows on the caller's), the interpreter runs, and the values it produced are moved
 * into a dictionary provider under the names the description gives them. A model that cannot be
 * run says which of its inputs was missing or wrong, or names the layer or the kind it refuses,
 * in the error's own message.
 */
#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLInternal.h"
#include "CharonMLModel.h"
#include "CharonMLPredict.h"
#include "CharonMLTensor.h"

/* --- the description ------------------------------------------------------------------------- */


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

- (instancetype)charon_initWithModel:(const charon_ml_model *)model
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
        MLFeatureDescription *described = [[MLFeatureDescription alloc] charon_initWithFeature:&model->inputs[index]];
        if (described != nil && model->inputs[index].name != NULL) {
            inputs[@(model->inputs[index].name)] = described;
        }
    }
    for (index = 0; index < model->output_count; index++) {
        MLFeatureDescription *described = [[MLFeatureDescription alloc] charon_initWithFeature:&model->outputs[index]];
        if (described != nil && model->outputs[index].name != NULL) {
            outputs[@(model->outputs[index].name)] = described;
        }
    }
    for (index = 0; index < model->training_input_count; index++) {
        MLFeatureDescription *described =
            [[MLFeatureDescription alloc] charon_initWithFeature:&model->training_inputs[index]];
        if (described != nil && model->training_inputs[index].name != NULL) {
            training[@(model->training_inputs[index].name)] = described;
        }
    }
    /* The metadata is the specification's own message, and all five of Core ML's own keys are
     * always there: measured against a real Core ML, a model that names no author at all answers
     * an empty string for the author rather than nil, and an empty dictionary for the map of
     * whatever else its author put in. A caller reading the metadata of a model that has none
     * therefore gets a dictionary with five entries whose values are empty, which is what a caller
     * can tell apart from a model whose metadata is not there at all. */
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
        const charon_ml_parameter *parameter = &model->parameters[index];
        MLParameterKey *key;
        id value;
        MLNumericConstraint *constraint;
        if (parameter->key == NULL) {
            continue;
        }
        key = [MLParameterKey charon_keyNamed:@(parameter->key)];
        if (key == nil) {
            continue;
        }
        value = parameter->type == CHARON_ML_FEATURE_INT64 ? @((int64_t)parameter->number)
                                                          : @(parameter->number);
        if (parameter->has_range) {
            constraint = [[MLNumericConstraint alloc] charon_initWithMinNumber:@(parameter->range_min)
                                                              maxNumber:@(parameter->range_max)
                                                     enumeratedNumbers:nil];
        } else {
            constraint = nil;
        }
        parameters[key] = [[MLParameterDescription alloc] charon_initWithKey:key
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

/* The description of one named function of the model, which is a description of its own: its own
 * inputs, its own outputs and the two names it answers under. A model with no named functions has
 * none of these, and the model's own description is the description of its only entry point. */
- (instancetype)charon_initWithFunction:(const charon_ml_function *)function
{
    MLModelDescription *built = [super init];
    if (built != nil) {
        size_t index;
        NSMutableDictionary *inputs = [NSMutableDictionary dictionary];
        NSMutableDictionary *outputs = [NSMutableDictionary dictionary];
        for (index = 0; index < function->input_count; index++) {
            MLFeatureDescription *described = [[MLFeatureDescription alloc] charon_initWithFeature:&function->inputs[index]];
            if (described != nil && function->inputs[index].name != NULL) {
                inputs[@(function->inputs[index].name)] = described;
            }
        }
        for (index = 0; index < function->output_count; index++) {
            MLFeatureDescription *described = [[MLFeatureDescription alloc] charon_initWithFeature:&function->outputs[index]];
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
    /* A model is updatable when its own container says so, which is the specification's own
     * field. This port does not train: it reads a container and runs it, and a model that names
     * itself updatable is one whose weights could be written back by a framework that trains,
     * which is not this one. The flag is therefore the model's own answer, and a caller that
     * asks may use it to decide whether to look for an update API -- which is absent here, and
     * says so. */
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

/* --- the configuration ------------------------------------------------------------------------ */


@implementation MLPredictionOptions {
    BOOL _usesCPUOnly;
    NSDictionary<NSString *, id> *_outputBackings;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        /* Core ML's own defaults for a fresh options object, both measured: NO for the CPU-only
         * flag, because the model is run where it chooses to run and a release with one unit is
         * that unit, and an empty dictionary for the backings -- not nil, so a caller that adds
         * one to it does not have to make it first. */
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

/* --- a model built in memory -------------------------------------------------------------------- */


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
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @"there were no specification bytes to make a model of");
        return nil;
    }
    /* The data is kept, and it is a copy of the caller's own: an asset outlives the data it was
     * made from -- it is handed to an asynchronous load -- and a data the caller has mutated or
     * freed in between would make a model out of bytes that are no longer the model's. The
     * bytes are checked here rather than at the load, so a caller that made an asset out of
     * something that is not a model is told at once instead of from a completion handler. */
    {
        charon_ml_model probe;
        char message[512];
        if (!charon_ml_model_read_data(&probe, specificationData.bytes, specificationData.length, message,
                                       sizeof message)) {
            charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @(message));
            return nil;
        }
        charon_ml_model_release(&probe);
    }
    asset->_specification = [specificationData copy];
    return asset;
}

+ (instancetype)modelAssetWithSpecificationData:(NSData *)specificationData
                                    blobMapping:(NSDictionary<NSURL *, NSData *> *)blobMapping
                                          error:(NSError **)error
{
    /* The blob mapping is for a model of a program, whose weights live in files beside it and
     * are named from the specification: this port reads no such model -- the interpreter refuses
     * the mlProgram form by name, and facts/CoreML/CoreML.md says so -- so a mapping of blobs to
     * put in place of those files has nothing to stand in for. A model that names no blob is the
     * ordinary case and is made the ordinary way, which is the same asset. */
    if (blobMapping.count == 0) {
        return [self modelAssetWithSpecificationData:specificationData error:error];
    }
    charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                    @"this model keeps its weights in blob files, which are the mlProgram form of a model and "
                    @"are not read by this port; the model is refused rather than run without its weights");
    return nil;
}

+ (instancetype)modelAssetWithURL:(NSURL *)compiledModelURL error:(NSError **)error
{
    NSData *container;
    if (compiledModelURL == nil || !compiledModelURL.isFileURL) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @"a model asset is read from a file's URL");
        return nil;
    }
    /* A compiled model is a bundle and its container is the coremldata.bin inside it, which is
     * where a compiled model keeps its program. A URL that is not a bundle is read as the
     * container itself, so an asset can be made of an .mlmodel file as readily as of one this
     * port compiled. */
    {
        BOOL directory = NO;
        NSString *inside = [compiledModelURL.path stringByAppendingPathComponent:@"coremldata.bin"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:inside]) {
            container = [NSData dataWithContentsOfFile:inside];
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:compiledModelURL.path isDirectory:&directory] &&
                   directory) {
            charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"the bundle at %@ holds no coremldata.bin, which is "
                                                       @"where a compiled model keeps its program", compiledModelURL.path]);
            return nil;
        } else {
            container = [NSData dataWithContentsOfFile:compiledModelURL.path];
        }
    }
    if (container.length == 0) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
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
        NSArray<NSString *> *names = [self charon_functionNamesWithError:&failure];
        if (handler != nil) {
            handler(names, names != nil ? nil : failure);
        }
    });
}

/* The names the model declares, in the order it declares them, and the empty list for a model
 * that declares none -- which is every model of a single entry point, and an empty list is the
 * answer for those rather than nil, because "this model has no named functions" is a fact about
 * the model and not a failure to read it. */
- (NSArray<NSString *> *)charon_functionNamesWithError:(NSError **)error
{
    charon_ml_model read;
    char message[512];
    NSMutableArray<NSString *> *names;
    size_t index;
    if (!charon_ml_model_read_data(&read, _specification.bytes, _specification.length, message, sizeof message)) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    names = [NSMutableArray arrayWithCapacity:read.function_count];
    for (index = 0; index < read.function_count; index++) {
        if (read.functions[index].name != NULL) {
            [names addObject:@(read.functions[index].name)];
        }
    }
    charon_ml_model_release(&read);
    return names;
}

/* The description of one named function, or of the model as a whole when the name is nil -- which
 * is what the specification's own default function is, and what a model with no named functions
 * has and only has. A model that names functions and is asked for one it does not have is
 * refused by name: the answer would otherwise be the whole model's description, which a caller
 * reading it would take for the function's own. */
- (MLModelDescription *)descriptionOfFunctionNamed:(NSString *)functionName error:(NSError **)error
{
    charon_ml_model read;
    char message[512];
    const charon_ml_function *function = NULL;
    MLModelDescription *description;
    if (!charon_ml_model_read_data(&read, _specification.bytes, _specification.length, message, sizeof message)) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    if (functionName != nil) {
        function = charon_ml_model_function_named(&read, [functionName UTF8String]);
        if (function == NULL) {
            NSMutableArray<NSString *> *named = [NSMutableArray array];
            size_t index;
            for (index = 0; index < read.function_count; index++) {
                if (read.functions[index].name != NULL) {
                    [named addObject:@(read.functions[index].name)];
                }
            }
            charon_ml_model_release(&read);
            charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"this model has no function called '%@'; it has %@",
                                                       functionName, [named componentsJoinedByString:@", "]]);
            return nil;
        }
    }
    description = function != NULL ? [[MLModelDescription alloc] charon_initWithFunction:function]
                                   : [[MLModelDescription alloc] charon_initWithModel:&read];
    charon_ml_model_release(&read);
    return description;
}

- (NSData *)charon_specificationData
{
    return _specification;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLModelAsset %lu bytes>", (unsigned long)_specification.length];
}

@end

/* --- the model --------------------------------------------------------------------------------- */


@implementation MLModel {
    charon_ml_model _model;
    MLModelDescription *_description;
    MLModelConfiguration *_configuration;
    NSURL *_url;
}

/* One prediction, and the whole of it. The values in are copied into the C's own set because the
 * interpreter owns what it is given -- a pipeline moves each sub-model's outputs on by name --
 * and a value that were a window on the caller's would be freed under it. The values out are the
 * interpreter's own, moved into a dictionary provider, and the type each is given is the one the
 * model declares for that output rather than the one the C's struct happens to hold, so a whole
 * number a model declared as a whole number is read as one. */
- (id<MLFeatureProvider>)predictionFromFeatures:(id<MLFeatureProvider>)input
                                          error:(NSError **)error
{
    /* The set of values is 1.1 MB of struct -- a value holds a dictionary of 256 pairs and an
     * array with its own shape -- and a model is 326 KB, so neither is an automatic variable on a
     * thread whose stack is a device's: the emulated iPad 2 faulted four bytes below its own stack
     * pointer on the first prediction, and the host, whose stack is eight megabytes, never would.
     * Both are on the heap, and every path out releases and frees them. */
    charon_ml_features *inputs = calloc(1, sizeof *inputs);
    charon_ml_features *outputs = calloc(1, sizeof *outputs);
    NSMutableDictionary<NSString *, MLFeatureValue *> *answered;
    char message[1024];
    NSEnumerator *names;
    id name;
    size_t index;

    if (input == nil || inputs == NULL || outputs == NULL) {
        free(inputs);
        free(outputs);
        charon_ml_error(error, CHARON_ML_ERROR_FEATURE_TYPE, @"a prediction needs a provider of values");
        return nil;
    }
    charon_ml_features_init(inputs);
    charon_ml_features_init(outputs);
    /* A feature the caller did not supply, or supplied as the undefined value that stands for
     * having not supplied it. The description says whether the model may do without it, and the
     * ones it may not are reported here, by name, rather than being left to the interpreter.
     *
     * The code is the framework-level one, and that is measured rather than assumed: a real Core ML
     * asked to predict without a required feature answers com.apple.CoreML with code 0, and the
     * name of the feature is in the message. The port used to let the failure come out of the
     * interpreter, which is where the same 0 came from by accident and without the name. */
    for (index = 0; index < _model.input_count; index++) {
        const charon_ml_feature *described = &_model.inputs[index];
        NSString *wanted = described->name != NULL ? @(described->name) : nil;
        MLFeatureValue *value = wanted != nil ? [input featureValueForName:wanted] : nil;
        if (described->optional != 0 || wanted == nil) {
            continue;
        }
        if (value == nil || value.isUndefined) {
            charon_ml_features_release(inputs);
            charon_ml_features_release(outputs);
            free(inputs);
            free(outputs);
            /* The release's own wording for a required feature the caller left out, measured
             * against this host's own Core ML over tools/coreml's vision_image container:
             * "Feature image is required but not specified." The type of the feature is not part of
             * it, so it is not in this sentence either. */
            charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"Feature %@ is required but not specified.", wanted]);
            return nil;
        }
    }
    names = [input.featureNames objectEnumerator];
    while ((name = [names nextObject]) != nil) {
        MLFeatureValue *value = [input featureValueForName:name];
        charon_ml_value held;
        if (value == nil || value.isUndefined) {
            /* An optional feature the caller left out, which a model may do without: the check
             * above has already refused the ones it may not. */
            continue;
        }
        held = charon_ml_value_owned_copy([value charonValue]);
        if (!charon_ml_features_put(inputs, [name UTF8String], held)) {
            charon_ml_features_release(inputs);
            free(inputs);
            free(outputs);
            charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                            [NSString stringWithFormat:@"there is no room for a feature named '%@'", name]);
            return nil;
        }
    }
    if (!charon_ml_predict(&_model, inputs, outputs, message, sizeof message)) {
        charon_ml_features_release(inputs);
        charon_ml_features_release(outputs);
        free(inputs);
        free(outputs);
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    charon_ml_features_release(inputs);
    free(inputs);
    answered = [NSMutableDictionary dictionaryWithCapacity:outputs->count];
    for (index = 0; index < outputs->count; index++) {
        const char *answer_name = outputs->entries[index].name;
        charon_ml_feature *described = NULL;
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
            type = charon_ml_feature_type_of(described->type);
        }
        value = [MLFeatureValue charon_featureValueWithOwned:&outputs->entries[index].value type:type];
        if (value == nil || answer_name == nil) {
            charon_ml_features_release(outputs);
            charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @"the model's answer had nowhere to go");
            free(outputs);
            return nil;
        }
        answered[@(answer_name)] = value;
    }
    charon_ml_features_release(outputs);
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
    /* The backing objects a caller proposed: an MLMultiArray it allocated itself, which the
     * answer is written into so that the caller never has to copy it out. A backing object that
     * does not fit the answer -- the wrong shape, the wrong element type, not an array at all --
     * is ignored rather than refused, which is what Core ML's own documentation says a framework
     * does with one it cannot use, and the caller finds out by comparing the answer with the
     * object it gave. */
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
                /* The numbers go into the caller's own buffer and the caller's object is what
                 * the answer then names, so `[prediction featureValueForName:@"out"]
                 * .multiArrayValue == backing` is true, which is the test Core ML documents for
                 * whether a backing object was used. */
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
    /* No options: the same run as the one with options, and Core ML's own options object is the
     * one a caller gets from a fresh MLPredictionOptions, so the run is the same either way. */
    return [self predictionsFromBatch:inputBatch options:[[MLPredictionOptions alloc] init] error:error];
}

- (id<MLBatchProvider>)predictionsFromBatch:(id<MLBatchProvider>)inputBatch
                                    options:(MLPredictionOptions *)options
                                      error:(NSError **)error
{
    NSMutableArray<id<MLFeatureProvider>> *answers;
    NSInteger index, count;
    if (inputBatch == nil) {
        charon_ml_error(error, CHARON_ML_ERROR_FEATURE_TYPE, @"a batch prediction needs a batch");
        return nil;
    }
    count = inputBatch.count;
    answers = [NSMutableArray arrayWithCapacity:(NSUInteger)(count > 0 ? count : 0)];
    for (index = 0; index < count; index++) {
        id<MLFeatureProvider> one = [inputBatch featuresAtIndex:index];
        id<MLFeatureProvider> answer;
        if (one == nil) {
            charon_ml_error(error, CHARON_ML_ERROR_FEATURE_TYPE,
                            [NSString stringWithFormat:@"the batch has %ld providers, and there is none at %ld",
                                                       (long)count, (long)index]);
            return nil;
        }
        answer = [self predictionFromFeatures:one options:options error:error];
        if (answer == nil) {
            /* Which element failed is part of the answer: a batch of a thousand where the
             * seven hundredth is wrong is a different thing to fix from a batch that is wrong. */
            if (error != NULL && *error != nil) {
                charon_ml_error(error, [*error code],
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
        charon_ml_error(error, CHARON_ML_ERROR_PARAMETERS, @"a parameter is asked for by its key");
        return nil;
    }
    for (index = 0; index < _model.parameter_count; index++) {
        const charon_ml_parameter *parameter = &_model.parameters[index];
        if (parameter->key == NULL || ![key.name isEqualToString:@(parameter->key)]) {
            continue;
        }
        if (key.scope != nil) {
            /* A scoped key is a parameter of one named part of a pipeline, and this port's
             * models name their parameters without a scope: there is no sub-model to scope one
             * to, so the answer is the model's own error for a parameter it does not have. */
            charon_ml_error(error, CHARON_ML_ERROR_PARAMETERS,
                            [NSString stringWithFormat:@"'%@' is a parameter of the part called '%@', and this "
                                                       @"model has no part of that name", key.name, key.scope]);
            return nil;
        }
        if (parameter->type == CHARON_ML_FEATURE_INT64) {
            return @((int64_t)parameter->number);
        }
        return @(parameter->number);
    }
    charon_ml_error(error, CHARON_ML_ERROR_PARAMETERS,
                    [NSString stringWithFormat:@"this model has no parameter called '%@'", key.name]);
    return nil;
}

- (MLModelDescription *)modelDescription
{
    /* Built once and kept: it is the same description for the life of the model, and building it
     * again for each call would walk the whole specification each time an application asks what a
     * model wants -- which is once per prediction, usually. */
    if (_description == nil) {
        _description = [[MLModelDescription alloc] charon_initWithModel:&_model];
    }
    return _description;
}

- (MLModelConfiguration *)configuration
{
    return _configuration;
}

- (void)dealloc
{
    charon_ml_model_release(&_model);
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
        /* The one I/O case a load has: measured against a real Core ML, which answers IO -- and
         * only IO -- for a URL that is not a file's. A file that is not there, and a file that is
         * not a model, are the generic case, which is what the same framework answers for those. */
        charon_ml_error(error, CHARON_ML_ERROR_IO,
                        @"a model is read from a file, and the URL given is not a file's");
        return nil;
    }
    if (!charon_ml_model_read(&_model, url.fileSystemRepresentation, message, sizeof message)) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @(message));
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
    /* On a queue of its own, because a model read from a slow store is the reason this method
     * exists: the caller's thread is not held up by a read it does not have to wait for. The
     * handler is called exactly once, with the model or with the reason there was none. */
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
            charon_ml_error(&failure, CHARON_ML_ERROR_GENERIC, @"there was no model asset to load");
        } else {
            model = [[MLModel alloc] charon_initWithContentsOfAsset:asset configuration:configuration error:&failure];
        }
        if (handler != nil) {
            handler(model, model != nil ? nil : failure);
        }
    });
}

/* A model out of an asset, which is the same read out of bytes rather than out of a file. */
- (instancetype)charon_initWithContentsOfAsset:(MLModelAsset *)asset
                           configuration:(MLModelConfiguration *)configuration
                                   error:(NSError **)error
{
    char message[1024];
    MLModel *built = [super init];
    if (built == nil) {
        return nil;
    }
    if (!charon_ml_model_read_data(&_model, asset.charon_specificationData.bytes, asset.charon_specificationData.length,
                                   message, sizeof message)) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    _configuration = configuration != nil ? configuration : [[MLModelConfiguration alloc] init];
    return built;
}

#pragma mark - compiling

/* A model compiled, which for this port means its container written into a bundle of the same
 * name. Apple's own compiled form is a private storage container this port does not read --
 * facts/CoreML/CoreML.md says so -- so what is written here is the specification's own message
 * under the name a compiled model keeps it, and a bundle written this way is read and run by
 * this port and by no other. It is a real, complete, working artefact rather than a refusal: a
 * caller that compiles a model to ship it in an app gets back a bundle that loads. */
/* A model compiled, which for this port means its container written into a bundle of the same
 * shape, under a name of its own in the temporary directory. Apple's own compiled form is a
 * private storage container this port does not read -- facts/CoreML/CoreML.md says so -- so what
 * is written here is the specification's own message under the name a compiled model keeps it,
 * and a bundle written this way is read and run by this port and by no other. It is a real,
 * complete, working artefact rather than a refusal: a caller that compiles a model to ship it in
 * an app gets back a URL it can load a model from, which is what Core ML promises. */
+ (NSURL *)charon_compiledModelAtURL:(NSURL *)modelURL error:(NSError **)error
{
    NSData *container = [NSData dataWithContentsOfFile:modelURL.path];
    NSString *name;
    NSString *directory;
    NSFileManager *files = [NSFileManager defaultManager];
    if (container.length == 0) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                        [NSString stringWithFormat:@"the model at %@ could not be read", modelURL.path]);
        return nil;
    }
    /* A compiled model is a bundle, and a bundle is a directory: the name is the model's own
     * name with .mlmodelc in place of .mlmodel, in a directory of this model's own so that two
     * compilations of two models in the same temporary directory do not meet. */
    name = [[[modelURL.path lastPathComponent] stringByDeletingPathExtension]
        stringByAppendingPathExtension:@"mlmodelc"];
    directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                           [@"charon-coreml-" stringByAppendingString:
                                                         [[NSUUID UUID] UUIDString]]];
    directory = [directory stringByAppendingPathComponent:name];
    if (![files createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL] ||
        ![[container copy] writeToFile:[directory stringByAppendingPathComponent:@"coremldata.bin"]
                           atomically:YES]) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC,
                        [NSString stringWithFormat:@"the bundle at %@ could not be written", directory]);
        return nil;
    }
    return [NSURL fileURLWithPath:directory];
}

+ (NSURL *)compileModelAtURL:(NSURL *)modelURL error:(NSError **)error
{
    if (modelURL == nil || !modelURL.isFileURL) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @"a model is compiled from a file's URL");
        return nil;
    }
    return [self charon_compiledModelAtURL:modelURL error:error];
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
