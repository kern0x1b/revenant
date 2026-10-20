#import <CoreML/CoreML.h>
#import "RevenantMLUpdateTask.h"
#import "RevenantMLBridge.h"
#import "RevenantMLProto.h"
#import "RevenantMLTrain.h"
#import "RevenantMLWrite.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

#define RevenantMLRefuse(...) NSLog(__VA_ARGS__)

@implementation MLTask {
    NSString *_taskIdentifier;
    MLTaskState _state;
    NSError *_error;
}

- (instancetype)init
{
    RevenantMLRefuse(@"CoreML: MLTask marks -init NS_UNAVAILABLE with the reason \"cannot construct MLTask"
                    @" without parameters\"; a task is made by the framework that runs it");
    return nil;
}

+ (instancetype)new
{
    RevenantMLRefuse(@"CoreML: MLTask marks +new NS_UNAVAILABLE for the same reason -init is");
    return nil;
}

- (instancetype)initForRevenantML
{
    self = [super init];
    if (self) {
        _taskIdentifier = [[NSUUID UUID] UUIDString];
        _state = MLTaskStateSuspended;
    }
    return self;
}

- (NSString *)taskIdentifier { return _taskIdentifier; }

- (MLTaskState)state
{
    @synchronized (self) {
        return _state;
    }
}

- (NSError *)error
{
    @synchronized (self) {
        return _error;
    }
}

- (void)revenant_ml_setState:(MLTaskState)state error:(NSError *)error
{
    @synchronized (self) {
        _state = state;
        _error = error;
    }
}

- (BOOL)revenant_ml_isCancelling
{
    return self.state == MLTaskStateCancelling;
}

- (void)resume
{
    @synchronized (self) {
        if (_state != MLTaskStateSuspended) {
            RevenantMLRefuse(@"CoreML: -[MLTask resume] was called on a task whose state is %ld, and MLTask"
                            @" describes resuming a Suspended task; nothing was changed",
                            (long)_state);
            return;
        }
        _state = MLTaskStateRunning;
    }
}

- (void)cancel
{
    @synchronized (self) {
        if (_state != MLTaskStateSuspended && _state != MLTaskStateRunning) {
            RevenantMLRefuse(@"CoreML: -[MLTask cancel] was called on a task whose state is %ld, and MLTask"
                            @" describes cancelling a task that is Suspended or Running; nothing was changed",
                            (long)_state);
            return;
        }
        _state = MLTaskStateCancelling;
    }
}

@end

@interface RevenantMLWritableWrappedModel : MLModel <MLWritable>
@end

@implementation RevenantMLWritableWrappedModel {
    NSURL *_snapshotURL;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url
                        configuration:(MLModelConfiguration *)configuration
                                error:(NSError **)error
{
    self = [super initWithContentsOfURL:url configuration:configuration error:error];
    if (self) {
        _snapshotURL = [url copy];
    }
    return self;
}

- (BOOL)writeToURL:(NSURL *)url error:(NSError * _Nullable * _Nullable)error
{
    NSData *container = [NSData dataWithContentsOfURL:_snapshotURL options:0 error:error];
    if (container == nil) {
        return NO;
    }
    return [container writeToURL:url options:NSDataWritingAtomic error:error];
}

- (void)dealloc
{
    [[NSFileManager defaultManager] removeItemAtURL:_snapshotURL error:nil];
}

@end

@interface MLUpdateTask ()
- (void)revenant_ml_run;
- (BOOL)revenant_ml_deliver:(MLUpdateProgressEvent)event metrics:(NSDictionary *)metrics;
- (nullable MLModel *)revenant_ml_snapshot:(NSError * _Nullable * _Nullable)error;
- (NSError *)revenant_ml_failure:(const char *)message;
@end

@implementation MLUpdateTask {
    NSURL *_modelURL;
    revenant_ml_node _document;
    revenant_ml_trainer *_trainer;
    MLUpdateProgressHandlers *_handlers;
    NSUInteger _count;
    size_t _inputCount, _outputCount;
    float *_inputs, *_targets;
    dispatch_queue_t _queue;
}

+ (nullable instancetype)updateTaskForModelAtURL:(NSURL *)modelURL
                                    trainingData:(id<MLBatchProvider>)trainingData
                                   configuration:(nullable MLModelConfiguration *)configuration
                               completionHandler:(void (^)(MLUpdateContext *context))completionHandler
                                           error:(NSError * _Nullable * _Nullable)error
{
    MLUpdateProgressHandlers *handlers = [[MLUpdateProgressHandlers alloc] initForEvents:0
                                                                         progressHandler:nil
                                                                       completionHandler:completionHandler];
    if (handlers == nil) {
        return nil;
    }
    return [self revenant_ml_taskForModelAtURL:modelURL trainingData:trainingData progressHandlers:handlers error:error];
}

+ (nullable instancetype)updateTaskForModelAtURL:(NSURL *)modelURL
                                    trainingData:(id<MLBatchProvider>)trainingData
                                   configuration:(nullable MLModelConfiguration *)configuration
                                progressHandlers:(MLUpdateProgressHandlers *)progressHandlers
                                           error:(NSError * _Nullable * _Nullable)error
{
    return [self revenant_ml_taskForModelAtURL:modelURL trainingData:trainingData progressHandlers:progressHandlers error:error];
}

+ (nullable instancetype)revenant_ml_taskForModelAtURL:(NSURL *)modelURL
                                        trainingData:(id<MLBatchProvider>)trainingData
                                    progressHandlers:(MLUpdateProgressHandlers *)progressHandlers
                                               error:(NSError * _Nullable * _Nullable)error
{
    if (modelURL == nil || !modelURL.isFileURL) {
        revenant_ml_error(error, REVENANT_ML_ERROR_IO, @"a model is trained from a file, and the URL given is not a file's");
        return nil;
    }
    NSData *container = [NSData dataWithContentsOfURL:modelURL options:0 error:error];
    if (container == nil) {
        return nil;
    }
    revenant_ml_node document;
    if (!revenant_ml_read(&document, container.bytes, container.length, "CoreML.Specification.Model")) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @"the file is not a model container the port can read");
        return nil;
    }
    char message[512] = "";
    revenant_ml_trainer *trainer = revenant_ml_trainer_new(&document, message, sizeof message);
    if (trainer == NULL) {
        revenant_ml_free(&document);
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    size_t inputCount = revenant_ml_trainer_input_count(trainer), outputCount = revenant_ml_trainer_output_count(trainer);
    NSInteger count = trainingData.count;

    float *inputs = count > 0 ? malloc(sizeof(float) * (size_t)count * inputCount) : NULL;
    float *targets = count > 0 ? malloc(sizeof(float) * (size_t)count * outputCount) : NULL;
    NSString *failure = nil;
    if (count <= 0) {
        failure = @"the training data holds no samples";
    } else if (inputs == NULL || targets == NULL) {
        failure = @"out of memory for the training samples";
    }
    for (NSInteger i = 0; failure == nil && i < count; i++) {
        id<MLFeatureProvider> sample = [trainingData featuresAtIndex:i];
        MLMultiArray *x = [sample featureValueForName:@"x"].multiArrayValue;
        MLMultiArray *t = [sample featureValueForName:@"t"].multiArrayValue;
        if (x == nil || t == nil || (size_t)x.count != inputCount || (size_t)t.count != outputCount) {
            failure = [NSString stringWithFormat:@"sample %ld has no image x of %zu values and target t of %zu values",
                       (long)i, inputCount, outputCount];
            break;
        }
        for (size_t k = 0; k < inputCount; k++) {
            inputs[(size_t)i * inputCount + k] = [x[k] floatValue];
        }
        for (size_t k = 0; k < outputCount; k++) {
            targets[(size_t)i * outputCount + k] = [t[k] floatValue];
        }
    }
    if (failure != nil) {
        free(inputs);
        free(targets);
        revenant_ml_trainer_free(trainer);
        revenant_ml_free(&document);
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, failure);
        return nil;
    }

    MLUpdateTask *task = [[MLUpdateTask alloc] initForRevenantML];
    task->_modelURL = [modelURL copy];
    task->_document = document;
    task->_trainer = trainer;
    task->_handlers = progressHandlers;
    task->_count = (NSUInteger)count;
    task->_inputCount = inputCount;
    task->_outputCount = outputCount;
    task->_inputs = inputs;
    task->_targets = targets;
    task->_queue = dispatch_queue_create("com.revenant.coreml.update", DISPATCH_QUEUE_SERIAL);
    return task;
}

- (void)resumeWithParameters:(NSDictionary<MLParameterKey *, id> *)updateParameters
{
    if (updateParameters.count > 0) {
        RevenantMLRefuse(@"CoreML: -[MLUpdateTask resumeWithParameters:] was given %lu parameters, and the port applies"
                        @" none of them yet; nothing was changed", (unsigned long)updateParameters.count);
        return;
    }
    [self resume];
}

- (void)resume
{
    MLTaskState before = self.state;
    [super resume];
    if (before == MLTaskStateSuspended && self.state == MLTaskStateRunning) {
        dispatch_async(_queue, ^{
            [self revenant_ml_run];
        });
    }
}

- (void)revenant_ml_run
{
    if (![self revenant_ml_deliver:MLUpdateProgressEventTrainingBegin metrics:@{}]) {
        return;
    }
    size_t minibatch = revenant_ml_trainer_minibatch_size(_trainer);
    long long epochs = revenant_ml_trainer_epochs(_trainer);
    for (long long epoch = 0; epoch < epochs; epoch++) {
        size_t index = 0;
        for (size_t first = 0; first < _count; first += minibatch, index++) {
            if ([self revenant_ml_isCancelling]) {
                return;
            }
            size_t samples = _count - first < minibatch ? _count - first : minibatch;
            char message[512] = "";
            if (!revenant_ml_trainer_step(_trainer, _inputs + first * _inputCount, _targets + first * _outputCount,
                                        samples, message, sizeof message)) {
                [self revenant_ml_setState:MLTaskStateFailed error:[self revenant_ml_failure:message]];
                return;
            }
            if (![self revenant_ml_deliver:MLUpdateProgressEventMiniBatchEnd
                                 metrics:@{MLMetricKey.miniBatchIndex: @(index)}]) {
                return;
            }
        }
        if (![self revenant_ml_deliver:MLUpdateProgressEventEpochEnd metrics:@{MLMetricKey.epochIndex: @(epoch)}]) {
            return;
        }
    }
    NSError *error = nil;
    MLModel *model = [self revenant_ml_snapshot:&error];
    if (model == nil) {
        [self revenant_ml_setState:MLTaskStateFailed error:error];
        return;
    }
    [self revenant_ml_setState:MLTaskStateCompleted error:nil];
    if (_handlers.revenant_ml_completionHandler) {
        MLUpdateContext *context = [[MLUpdateContext alloc] initForRevenantMLWithTask:self model:model
                                                                             event:(MLUpdateProgressEvent)0
                                                                           metrics:@{}
                                                                        parameters:@{}];
        _handlers.revenant_ml_completionHandler(context);
    }
}

- (BOOL)revenant_ml_deliver:(MLUpdateProgressEvent)event metrics:(NSDictionary *)metrics
{
    void (^progress)(MLUpdateContext *) = _handlers.revenant_ml_progressHandler;
    if (progress == nil || (_handlers.revenant_ml_interestedEvents & event) == 0) {
        return YES;
    }
    NSError *error = nil;
    MLModel *model = [self revenant_ml_snapshot:&error];
    if (model == nil) {
        [self revenant_ml_setState:MLTaskStateFailed error:error];
        return NO;
    }
    MLUpdateContext *context = [[MLUpdateContext alloc] initForRevenantMLWithTask:self model:model event:event
                                                                         metrics:metrics parameters:@{}];
    progress(context);
    return YES;
}

- (nullable MLModel *)revenant_ml_snapshot:(NSError * _Nullable * _Nullable)error
{
    if (!revenant_ml_trainer_store(_trainer, &_document)) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @"the trained values do not fit the model's document");
        return nil;
    }
    unsigned char *bytes = NULL;
    size_t length = 0;
    if (!revenant_ml_write(&_document, &bytes, &length)) {
        revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC, @"the model's document could not be encoded");
        return nil;
    }
    NSData *container = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:YES];
    NSString *name = [NSString stringWithFormat:@"revenant-update-%@.mlmodel", [[NSUUID UUID] UUIDString]];
    NSURL *url = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
    if (![container writeToURL:url options:NSDataWritingAtomic error:error]) {
        return nil;
    }
    return [[RevenantMLWritableWrappedModel alloc] initWithContentsOfURL:url configuration:nil error:error];
}

- (NSError *)revenant_ml_failure:(const char *)message
{
    NSError *error = nil;
    revenant_ml_error(&error, REVENANT_ML_ERROR_GENERIC, [NSString stringWithUTF8String:message]);
    return error;
}

- (void)dealloc
{
    revenant_ml_trainer_free(_trainer);
    revenant_ml_free(&_document);
    free(_inputs);
    free(_targets);
}

@end

@implementation MLUpdateContext {
    MLUpdateTask *_task;
    MLModel *_model;
    MLUpdateProgressEvent _event;
    NSDictionary *_metrics;
    NSDictionary *_parameters;
}

- (instancetype)initForRevenantMLWithTask:(MLUpdateTask *)task
                                 model:(MLModel *)model
                                 event:(MLUpdateProgressEvent)event
                               metrics:(NSDictionary *)metrics
                            parameters:(NSDictionary *)parameters
{
    MLUpdateContext *made = [super init];
    if (made) {
        made->_task = task;
        made->_model = model;
        made->_event = event;
        made->_metrics = [metrics copy];
        made->_parameters = [parameters copy];
    }
    return made;
}

- (MLUpdateTask *)task { return _task; }
- (MLModel *)model { return _model; }
- (MLUpdateProgressEvent)event { return _event; }
- (NSDictionary<MLMetricKey *, id> *)metrics { return _metrics; }
- (NSDictionary<MLParameterKey *, id> *)parameters { return _parameters; }

@end

@implementation MLUpdateProgressHandlers {
    MLUpdateProgressEvent _interestedEvents;
    void (^_progressHandler)(MLUpdateContext *);
    void (^_completionHandler)(MLUpdateContext *);
}

- (instancetype)initForEvents:(MLUpdateProgressEvent)interestedEvents
              progressHandler:(void (^)(MLUpdateContext *))progressHandler
            completionHandler:(void (^)(MLUpdateContext *))completionHandler
{
    if (!completionHandler) {
        RevenantMLRefuse(@"CoreML: MLUpdateProgressHandlers declares the completion handler nonnull and"
                        @" none was given, so no handlers were registered");
        return nil;
    }
    if ((self = [super init])) {
        _interestedEvents = interestedEvents;
        _progressHandler = progressHandler;
        _completionHandler = completionHandler;
    }
    return self;
}

- (instancetype)init
{
    RevenantMLRefuse(@"CoreML: MLUpdateProgressHandlers marks -init NS_UNAVAILABLE with the reason \"cannot construct"
                    @" MLUpdateTask without parameters\" - the header's own wording, and it names the other class;"
                    @" use -initForEvents:progressHandler:completionHandler:");
    return nil;
}

+ (instancetype)new
{
    RevenantMLRefuse(@"CoreML: MLUpdateProgressHandlers marks +new NS_UNAVAILABLE for the same reason -init is");
    return nil;
}

- (MLUpdateProgressEvent)revenant_ml_interestedEvents { return _interestedEvents; }
- (void (^)(MLUpdateContext *))revenant_ml_progressHandler { return _progressHandler; }
- (void (^)(MLUpdateContext *))revenant_ml_completionHandler { return _completionHandler; }

@end
