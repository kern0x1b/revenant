// The four Core ML update classes - MLTask, MLUpdateTask, MLUpdateContext and MLUpdateProgressHandlers - from
// MLTask.h, MLUpdateTask.h, MLUpdateContext.h and MLUpdateProgressHandlers.h of the iPhoneOS 16.4 surface, and
// the training that MLUpdateTask runs, with the MLWritable adopter its result is handed back on.
//
// Availability, measured on the 16.4 headers. The class is API_AVAILABLE(ios(13.0)) (MLUpdateTask.h:19), and so
// are two of its four constructors: the ones that take a configuration, updateTaskForModelAtURL:...configuration:
// completionHandler:error: (:23) and ...configuration:progressHandlers:error: (:36), carry no annotation of their
// own and so inherit the class's 13.0. The other two (:30 and :43) are API_AVAILABLE(ios(14.0)) at :33 and :46.
// The two iOS 13 constructors are here; the two iOS 14 ones are in CoreMLUpdate14.m, and they reach the same
// training through CharonMLUpdateTask.h.
//
// WHAT MLTask IS: the header describes it as an object that handles changes of state and the basic control of a
// task (MLTask.h:26-27). Its three properties are a taskIdentifier (:32-33), a state (:35-36) and an error
// (:38-39), and its two methods are given as their effect and nothing else:
//     -resume  the call resumes the task and sets its state to Running (MLTask.h:41-42).
//     -cancel  the call starts cancelling the task and sets its state to Cancelling (MLTask.h:44-45).
// The states are MLTaskState's own five cases (MLTask.h:16-24): Suspended 1, Running 2, Cancelling 3, Completed 4,
// Failed 5. A transition the header does not describe is refused by name, with the state printed, rather than forced.
//
// -init and +new are NS_UNAVAILABLE on MLTask (MLTask.h:47-51) and again on MLUpdateTask (MLUpdateTask.h:53-56) and
// MLUpdateProgressHandlers (MLUpdateProgressHandlers.h:25-29), each with the header's own reason, so each refuses by
// name. The port's own constructors reach NSObject's -init through -initForCharonML, not through the refusal.
//
// MLUpdateContext declares five readonly properties (MLUpdateContext.h:24-36) and NO initialiser, so the only way in
// is the seam below: the training loop builds a context and hands it to the handlers, as the release does.
//
// WHAT IS MEASURED AND WHAT IS NOT. The training is the host's MLUpdateTask on the CPU, checked against the host's
// weights at every event by tests/backports/host/coreml-update: the updatable weights agree to within the bound the
// run states. The loss the host reports is NOT the port's: the port reports no lossValue, because the host's value
// is not a function the port has identified (facts/CoreML/Update13.md). The completion context's event is 0, as the
// host's is. The host's cancel and failure paths are not measured here, and the port's are named where they are.

#import <CoreML/CoreML.h>
#import "CharonMLUpdateTask.h"
#import "CharonMLBridge.h"
#import "CharonMLProto.h"
#import "CharonMLTrain.h"
#import "CharonMLWrite.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// What MPS's CharonMPSRefuse is - an NSLog - under this folder's own name, and a macro rather than a function so
// that no CoreML file depends on another one's symbols.
#define CharonMLRefuse(...) NSLog(__VA_ARGS__)

@implementation MLTask {
    NSString *_taskIdentifier;
    MLTaskState _state;
    NSError *_error;
}

// MLTask.h:47-51, "cannot construct MLTask without parameters". A task with no identifier and no state is not a
// task, so this refuses rather than making one whose every getter answers nil.
- (instancetype)init
{
    CharonMLRefuse(@"CoreML: MLTask marks -init NS_UNAVAILABLE with the reason \"cannot construct MLTask"
                    @" without parameters\"; a task is made by the framework that runs it");
    return nil;
}

+ (instancetype)new
{
    // NSObject's +new is [[self alloc] init], so the refusal above is what this would reach anyway; naming it
    // here is what makes the refusal the caller's own answer rather than a chain through NSObject's convenience.
    CharonMLRefuse(@"CoreML: MLTask marks +new NS_UNAVAILABLE for the same reason -init is");
    return nil;
}

// The port's constructor for its tasks: NSObject's -init, which -init above refuses, with the identifier and the
// Suspended state a new task has.
- (instancetype)initForCharonML
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

- (void)charon_ml_setState:(MLTaskState)state error:(NSError *)error
{
    @synchronized (self) {
        _state = state;
        _error = error;
    }
}

- (BOOL)charon_ml_isCancelling
{
    return self.state == MLTaskStateCancelling;
}

// -resume, MLTask.h:41-42, moves the task to Running. The state it resumes FROM is the one the header names, so a
// task that is not suspended says so and does not move.
- (void)resume
{
    @synchronized (self) {
        if (_state != MLTaskStateSuspended) {
            CharonMLRefuse(@"CoreML: -[MLTask resume] was called on a task whose state is %ld, and MLTask"
                            @" describes resuming a Suspended task; nothing was changed",
                            (long)_state);
            return;
        }
        _state = MLTaskStateRunning;
    }
}

// -cancel, MLTask.h:44-45: the call moves the task into the Cancelling state. A task that has already finished,
// failed or is already cancelling has nothing left to cancel.
- (void)cancel
{
    @synchronized (self) {
        if (_state != MLTaskStateSuspended && _state != MLTaskStateRunning) {
            CharonMLRefuse(@"CoreML: -[MLTask cancel] was called on a task whose state is %ld, and MLTask"
                            @" describes cancelling a task that is Suspended or Running; nothing was changed",
                            (long)_state);
            return;
        }
        _state = MLTaskStateCancelling;
    }
}

@end

// The model an update hands back, MLUpdateContext.model: an MLModel that adopts MLWritable (MLWritable.h:13-17).
// The host adopts the protocol on a class of its own (MLWritableWrappedModel); this one carries the port's name,
// because a private class of the host is named with the Charon prefix in the port. It is a file of the snapshot the
// training wrote, and writing it copies that file, which is the container the writer encodes.
@interface CharonMLWritableWrappedModel : MLModel <MLWritable>
@end

@implementation CharonMLWritableWrappedModel {
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

// The snapshot is a file of the temporary folder, made for this model, and it is removed with the model.
- (void)dealloc
{
    [[NSFileManager defaultManager] removeItemAtURL:_snapshotURL error:nil];
}

@end

// MLUpdateTask is MLTask's one subclass (MLUpdateTask.h:20). Its state is MLTask's; what it adds is the training
// the port runs for a task, and the two constructors of iOS 13 that take a configuration.
@interface MLUpdateTask ()
- (void)charon_ml_run;
- (BOOL)charon_ml_deliver:(MLUpdateProgressEvent)event metrics:(NSDictionary *)metrics;
- (nullable MLModel *)charon_ml_snapshot:(NSError * _Nullable * _Nullable)error;
- (NSError *)charon_ml_failure:(const char *)message;
@end

@implementation MLUpdateTask {
    NSURL *_modelURL;
    charon_ml_node _document;          // the specification tree of the model, which the trainer's weights go back into
    charon_ml_trainer *_trainer;
    MLUpdateProgressHandlers *_handlers;
    NSUInteger _count;                 // the training samples, in the order the batch provider gives them
    size_t _inputCount, _outputCount;
    float *_inputs, *_targets;         // the samples flattened: _count images, and _count vectors of the output size
    dispatch_queue_t _queue;           // the training runs here, one update at a time, and so do the handlers
}

// MLUpdateTask.h:23-27, with the configuration and the completion handler. The configuration is not used: the port
// trains on the CPU, which is what the host's tests run on. The completion handler is the handlers' completion, and
// no progress events are asked for.
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
    return [self charon_ml_taskForModelAtURL:modelURL trainingData:trainingData progressHandlers:handlers error:error];
}

// MLUpdateTask.h:36-41, with the configuration and the progress handlers. The configuration is not used (see above).
+ (nullable instancetype)updateTaskForModelAtURL:(NSURL *)modelURL
                                    trainingData:(id<MLBatchProvider>)trainingData
                                   configuration:(nullable MLModelConfiguration *)configuration
                                progressHandlers:(MLUpdateProgressHandlers *)progressHandlers
                                           error:(NSError * _Nullable * _Nullable)error
{
    return [self charon_ml_taskForModelAtURL:modelURL trainingData:trainingData progressHandlers:progressHandlers error:error];
}

+ (nullable instancetype)charon_ml_taskForModelAtURL:(NSURL *)modelURL
                                        trainingData:(id<MLBatchProvider>)trainingData
                                    progressHandlers:(MLUpdateProgressHandlers *)progressHandlers
                                               error:(NSError * _Nullable * _Nullable)error
{
    if (modelURL == nil || !modelURL.isFileURL) {
        charon_ml_error(error, CHARON_ML_ERROR_IO, @"a model is trained from a file, and the URL given is not a file's");
        return nil;
    }
    NSData *container = [NSData dataWithContentsOfURL:modelURL options:0 error:error];
    if (container == nil) {
        return nil;
    }
    charon_ml_node document;
    if (!charon_ml_read(&document, container.bytes, container.length, "CoreML.Specification.Model")) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @"the file is not a model container the port can read");
        return nil;
    }
    char message[512] = "";
    charon_ml_trainer *trainer = charon_ml_trainer_new(&document, message, sizeof message);
    if (trainer == NULL) {
        charon_ml_free(&document);
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @(message));
        return nil;
    }
    size_t inputCount = charon_ml_trainer_input_count(trainer), outputCount = charon_ml_trainer_output_count(trainer);
    NSInteger count = trainingData.count;

    // The samples, flattened in the order the batch provider gives them. The feature names are x (the image) and t
    // (the target the loss reads), which is what the generated models of the host tests name them.
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
        charon_ml_trainer_free(trainer);
        charon_ml_free(&document);
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, failure);
        return nil;
    }

    MLUpdateTask *task = [[MLUpdateTask alloc] initForCharonML];
    task->_modelURL = [modelURL copy];
    task->_document = document;
    task->_trainer = trainer;
    task->_handlers = progressHandlers;
    task->_count = (NSUInteger)count;
    task->_inputCount = inputCount;
    task->_outputCount = outputCount;
    task->_inputs = inputs;
    task->_targets = targets;
    task->_queue = dispatch_queue_create("com.charon.coreml.update", DISPATCH_QUEUE_SERIAL);
    return task;
}

// -resumeWithParameters:, MLUpdateTask.h:50. The parameters the host accepts here (the learning rate, the momentum
// and the rest, MLParameterKey) are not applied by the port yet, so a call that gives any refuses by name and does
// nothing: the task is not started with values the port would silently ignore.
- (void)resumeWithParameters:(NSDictionary<MLParameterKey *, id> *)updateParameters
{
    if (updateParameters.count > 0) {
        CharonMLRefuse(@"CoreML: -[MLUpdateTask resumeWithParameters:] was given %lu parameters, and the port applies"
                        @" none of them yet; nothing was changed", (unsigned long)updateParameters.count);
        return;
    }
    [self resume];
}

// -resume is MLTask's, and for an update it starts the training: the state moves to Running as the header says, and
// the loop runs on the task's queue. A resume that does not move a Suspended task to Running starts nothing.
- (void)resume
{
    MLTaskState before = self.state;
    [super resume];
    if (before == MLTaskStateSuspended && self.state == MLTaskStateRunning) {
        dispatch_async(_queue, ^{
            [self charon_ml_run];
        });
    }
}

// The training loop: the training-begin event, then for each epoch the mini-batches in file order with a
// mini-batch-end event after each, and an epoch-end event after the last. The mini-batch index counts within the
// epoch, as the host's does. The loop stops at the next mini-batch boundary once the task is cancelled, and a failed
// step or snapshot fails the task with the reason; neither calls the completion handler, which the host's measured
// behaviour for those two paths does not say (facts/CoreML/Update13.md names it).
- (void)charon_ml_run
{
    if (![self charon_ml_deliver:MLUpdateProgressEventTrainingBegin metrics:@{}]) {
        return;
    }
    size_t minibatch = charon_ml_trainer_minibatch_size(_trainer);
    long long epochs = charon_ml_trainer_epochs(_trainer);
    for (long long epoch = 0; epoch < epochs; epoch++) {
        size_t index = 0;
        for (size_t first = 0; first < _count; first += minibatch, index++) {
            if ([self charon_ml_isCancelling]) {
                return;
            }
            size_t samples = _count - first < minibatch ? _count - first : minibatch;
            char message[512] = "";
            if (!charon_ml_trainer_step(_trainer, _inputs + first * _inputCount, _targets + first * _outputCount,
                                        samples, message, sizeof message)) {
                [self charon_ml_setState:MLTaskStateFailed error:[self charon_ml_failure:message]];
                return;
            }
            if (![self charon_ml_deliver:MLUpdateProgressEventMiniBatchEnd
                                 metrics:@{MLMetricKey.miniBatchIndex: @(index)}]) {
                return;
            }
        }
        if (![self charon_ml_deliver:MLUpdateProgressEventEpochEnd metrics:@{MLMetricKey.epochIndex: @(epoch)}]) {
            return;
        }
    }
    NSError *error = nil;
    MLModel *model = [self charon_ml_snapshot:&error];
    if (model == nil) {
        [self charon_ml_setState:MLTaskStateFailed error:error];
        return;
    }
    [self charon_ml_setState:MLTaskStateCompleted error:nil];
    if (_handlers.charon_ml_completionHandler) {
        MLUpdateContext *context = [[MLUpdateContext alloc] initForCharonMLWithTask:self model:model
                                                                             event:(MLUpdateProgressEvent)0
                                                                           metrics:@{}
                                                                        parameters:@{}];
        _handlers.charon_ml_completionHandler(context);
    }
}

// Calls the progress handler for an event it asked for, with the model as the training stands at that event. Returns
// NO when the task has failed, which stops the loop.
- (BOOL)charon_ml_deliver:(MLUpdateProgressEvent)event metrics:(NSDictionary *)metrics
{
    void (^progress)(MLUpdateContext *) = _handlers.charon_ml_progressHandler;
    if (progress == nil || (_handlers.charon_ml_interestedEvents & event) == 0) {
        return YES;
    }
    NSError *error = nil;
    MLModel *model = [self charon_ml_snapshot:&error];
    if (model == nil) {
        [self charon_ml_setState:MLTaskStateFailed error:error];
        return NO;
    }
    MLUpdateContext *context = [[MLUpdateContext alloc] initForCharonMLWithTask:self model:model event:event
                                                                         metrics:metrics parameters:@{}];
    progress(context);
    return YES;
}

// The model as the training stands now: the trainer's weights are written into the document, the document is encoded
// as the container, and the container is a file the model is read from.
- (nullable MLModel *)charon_ml_snapshot:(NSError * _Nullable * _Nullable)error
{
    if (!charon_ml_trainer_store(_trainer, &_document)) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @"the trained values do not fit the model's document");
        return nil;
    }
    unsigned char *bytes = NULL;
    size_t length = 0;
    if (!charon_ml_write(&_document, &bytes, &length)) {
        charon_ml_error(error, CHARON_ML_ERROR_GENERIC, @"the model's document could not be encoded");
        return nil;
    }
    NSData *container = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:YES];
    NSString *name = [NSString stringWithFormat:@"charon-update-%@.mlmodel", [[NSUUID UUID] UUIDString]];
    NSURL *url = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
    if (![container writeToURL:url options:NSDataWritingAtomic error:error]) {
        return nil;
    }
    return [[CharonMLWritableWrappedModel alloc] initWithContentsOfURL:url configuration:nil error:error];
}

- (NSError *)charon_ml_failure:(const char *)message
{
    NSError *error = nil;
    charon_ml_error(&error, CHARON_ML_ERROR_GENERIC, [NSString stringWithUTF8String:message]);
    return error;
}

- (void)dealloc
{
    charon_ml_trainer_free(_trainer);
    charon_ml_free(&_document);
    free(_inputs);
    free(_targets);
}

@end

// MLUpdateContext declares five readonly properties and no initialiser (MLUpdateContext.h:21-38), so the one way in
// is the seam in CharonMLUpdateTask.h, and it is on the class because the five values are this class's own state.
@implementation MLUpdateContext {
    MLUpdateTask *_task;
    MLModel *_model;
    MLUpdateProgressEvent _event;
    NSDictionary *_metrics;
    NSDictionary *_parameters;
}

- (instancetype)initForCharonMLWithTask:(MLUpdateTask *)task
                                 model:(MLModel *)model
                                 event:(MLUpdateProgressEvent)event
                               metrics:(NSDictionary *)metrics
                            parameters:(NSDictionary *)parameters
{
    // The result is held in a local and not assigned to self, because a selector that does not begin with "init" is
    // not in the init family and clang refuses `self =` in one - measured on this file. The local is typed with the
    // class rather than instancetype because this clang rejects instancetype as a variable type at -target
    // armv7-apple-ios6.0, and a method signature is the only place the rest of this package spells it.
    MLUpdateContext *made = [super init];
    if (made) {
        // Each of the five is a strong ivar, so storing one retains it and storing another releases the one held,
        // and a caller that hands nil is answered nil rather than a stand-in.
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

// MLUpdateProgressHandlers.h:17-30 gives the class as the place an application sets its handlers, with one
// initializer that takes them, and -init and +new unavailable. The two blocks are strong ivars, which is what ARC
// copies a block into, so what the caller registers outlives this method.
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
        CharonMLRefuse(@"CoreML: MLUpdateProgressHandlers declares the completion handler nonnull and"
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
    CharonMLRefuse(@"CoreML: MLUpdateProgressHandlers marks -init NS_UNAVAILABLE with the reason \"cannot construct"
                    @" MLUpdateTask without parameters\" - the header's own wording, and it names the other class;"
                    @" use -initForEvents:progressHandler:completionHandler:");
    return nil;
}

+ (instancetype)new
{
    CharonMLRefuse(@"CoreML: MLUpdateProgressHandlers marks +new NS_UNAVAILABLE for the same reason -init is");
    return nil;
}

- (MLUpdateProgressEvent)charon_ml_interestedEvents { return _interestedEvents; }
- (void (^)(MLUpdateContext *))charon_ml_progressHandler { return _progressHandler; }
- (void (^)(MLUpdateContext *))charon_ml_completionHandler { return _completionHandler; }

@end
