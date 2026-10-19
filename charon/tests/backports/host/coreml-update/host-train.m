#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>

static NSArray<id<MLFeatureProvider>> *samples_from(NSData *inputs, NSData *targets, NSUInteger count)
{
    NSMutableArray *providers = [NSMutableArray arrayWithCapacity:count];
    const float *x = inputs.bytes;
    const float *t = targets.bytes;
    for (NSUInteger i = 0; i < count; i++) {
        NSError *error = nil;
        MLMultiArray *image = [[MLMultiArray alloc] initWithShape:@[@1, @6, @6] dataType:MLMultiArrayDataTypeFloat32 error:&error];
        MLMultiArray *target = [[MLMultiArray alloc] initWithShape:@[@3] dataType:MLMultiArrayDataTypeFloat32 error:&error];
        memcpy(image.dataPointer, x + i * 36, 36 * sizeof(float));
        memcpy(target.dataPointer, t + i * 3, 3 * sizeof(float));
        MLDictionaryFeatureProvider *provider = [[MLDictionaryFeatureProvider alloc]
            initWithDictionary:@{@"x": image, @"t": target} error:&error];
        if (provider == nil) {
            fprintf(stderr, "feature provider: %s\n", error.localizedDescription.UTF8String);
            exit(1);
        }
        [providers addObject:provider];
    }
    return providers;
}

static BOOL dump_model(MLModel *model, NSString *path, NSError **error)
{
    NSMutableString *text = [NSMutableString string];
    NSArray<NSString *> *layers = @[@"conv", @"ip"];
    NSArray<NSString *> *kinds = @[@"convolution", @"innerProduct"];
    for (NSUInteger i = 0; i < layers.count; i++) {
        [text appendFormat:@"layer %@ %@\n", layers[i], kinds[i]];
        NSArray<NSArray *> *tensors = @[@[@"weights", MLParameterKey.weights], @[@"bias", MLParameterKey.biases]];
        for (NSArray *tensor in tensors) {
            NSError *keyError = nil;
            MLParameterKey *key = [(MLParameterKey *)tensor[1] scopedTo:layers[i]];
            MLMultiArray *array = [model parameterValueForKey:key error:&keyError];
            if (array == nil) {
                if (error) *error = keyError;
                return NO;
            }
            [text appendFormat:@"%@ %lu", tensor[0], (unsigned long)array.count];
            for (NSUInteger k = 0; k < array.count; k++) {
                [text appendFormat:@" %.9g", [array[k] doubleValue]];
            }
            [text appendString:@"\n"];
        }
    }
    return [text writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:error];
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc != 6) {
            fprintf(stderr, "usage: host-train MODEL.mlmodel INPUT.f32 TARGET.f32 OUTDIR SAMPLES\n");
            return 2;
        }
        NSURL *modelURL = [NSURL fileURLWithPath:@(argv[1])];
        NSString *outDir = @(argv[4]);
        NSUInteger count = (NSUInteger)atol(argv[5]);
        NSData *inputs = [NSData dataWithContentsOfFile:@(argv[2])];
        NSData *targets = [NSData dataWithContentsOfFile:@(argv[3])];
        if (inputs.length != count * 36 * sizeof(float) || targets.length != count * 3 * sizeof(float)) {
            fprintf(stderr, "the data files do not hold %lu samples\n", (unsigned long)count);
            return 2;
        }

        NSError *error = nil;
        NSURL *compiled = [MLModel compileModelAtURL:modelURL error:&error];
        if (compiled == nil) {
            fprintf(stderr, "compile: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        MLArrayBatchProvider *trainingData = [[MLArrayBatchProvider alloc] initWithFeatureProviderArray:samples_from(inputs, targets, count)];
        MLModelConfiguration *configuration = [[MLModelConfiguration alloc] init];
        configuration.computeUnits = MLComputeUnitsCPUOnly;

        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block NSUInteger step = 0;
        MLUpdateProgressEvent events = MLUpdateProgressEventTrainingBegin | MLUpdateProgressEventEpochEnd | MLUpdateProgressEventMiniBatchEnd;
        MLUpdateProgressHandlers *handlers = [[MLUpdateProgressHandlers alloc]
            initForEvents:events
          progressHandler:^(MLUpdateContext *context) {
            NSString *name = context.event == MLUpdateProgressEventTrainingBegin ? @"training-begin"
                : context.event == MLUpdateProgressEventEpochEnd ? @"epoch-end" : @"mini-batch-end";
            NSNumber *loss = context.metrics[MLMetricKey.lossValue];
            NSNumber *epoch = context.metrics[MLMetricKey.epochIndex];
            NSNumber *miniBatch = context.metrics[MLMetricKey.miniBatchIndex];
            NSString *file = [outDir stringByAppendingPathComponent:[NSString stringWithFormat:@"step-%03lu.dump", (unsigned long)step]];
            NSError *writeError = nil;
            BOOL written = dump_model(context.model, file, &writeError);
            printf("step %lu %s epoch %s minibatch %s loss %s snapshot %s written %d\n",
                   (unsigned long)step, name.UTF8String,
                   epoch ? [NSString stringWithFormat:@"%@", epoch].UTF8String : "-",
                   miniBatch ? [NSString stringWithFormat:@"%@", miniBatch].UTF8String : "-",
                   loss ? [NSString stringWithFormat:@"%.17g", loss.doubleValue].UTF8String : "-",
                   file.lastPathComponent.UTF8String, written);
            if (!written) {
                fprintf(stderr, "snapshot: %s\n", writeError.localizedDescription.UTF8String);
            }
            step++;
          }
          completionHandler:^(MLUpdateContext *context) {
            NSError *writeError = nil;
            NSString *file = [outDir stringByAppendingPathComponent:@"final.dump"];
            BOOL written = dump_model(context.model, file, &writeError);
            printf("completed event %ld snapshot final.dump written %d\n", (long)context.event, written);
            dispatch_semaphore_signal(done);
          }];

        MLUpdateTask *task = [MLUpdateTask updateTaskForModelAtURL:compiled
                                                      trainingData:trainingData
                                                     configuration:configuration
                                                  progressHandlers:handlers
                                                             error:&error];
        if (task == nil) {
            fprintf(stderr, "task: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        printf("state before resume %ld\n", (long)task.state);
        [task resume];
        long waited = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_SEC));
        printf("state after completion %ld error %s waited %s\n", (long)task.state,
               task.error ? task.error.localizedDescription.UTF8String : "none", waited == 0 ? "no" : "timeout");
        return waited == 0 ? 0 : 1;
    }
}
