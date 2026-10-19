/* The seams between the files that make up the model-update classes: MLTask and MLUpdateProgressHandlers are
 * read here, and MLUpdateTask's training is started here. The public declarations stay in the framework's
 * headers; these are the port's own, and only the update files import this one. */
#ifndef CHARON_ML_UPDATE_TASK_H
#define CHARON_ML_UPDATE_TASK_H

#import <CoreML/CoreML.h>

NS_ASSUME_NONNULL_BEGIN

@interface MLTask (CharonMLUpdateTask)
/* The designated constructor of the port's tasks. MLTask's -init refuses by name, so the update classes build
 * themselves through this, which reaches NSObject's -init and not the refusal. */
- (instancetype)initForCharonML;
/* Moves the task to a state under the task's lock, with the error that a failed task carries. */
- (void)charon_ml_setState:(MLTaskState)state error:(nullable NSError *)error;
- (BOOL)charon_ml_isCancelling;
@end

@interface MLUpdateProgressHandlers (CharonMLUpdateTask)
- (MLUpdateProgressEvent)charon_ml_interestedEvents;
- (nullable void (^)(MLUpdateContext *))charon_ml_progressHandler;
- (void (^)(MLUpdateContext *))charon_ml_completionHandler;
@end

/* The model's reading initialiser with its configuration, which MLModel.m implements and the public header does not
 * declare; the update's result is a model read from the snapshot file, and it is read this way. */
@interface MLModel (CharonMLUpdateTask)
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url
                                 configuration:(nullable MLModelConfiguration *)configuration
                                         error:(NSError * _Nullable * _Nullable)error;
@end

@interface MLUpdateContext (CharonMLUpdateContext)
/* The five values a context carries; the framework has no initialiser for a context (MLUpdateContext.h:21-38). */
- (instancetype)initForCharonMLWithTask:(MLUpdateTask *)task
                                 model:(MLModel *)model
                                 event:(MLUpdateProgressEvent)event
                               metrics:(NSDictionary *)metrics
                            parameters:(NSDictionary *)parameters;
@end

@interface MLUpdateTask (CharonMLUpdateTask)
/* The one constructor the update classes share: the model is read from a file, its trainer is made, the training
 * samples are taken from the batch provider, and the task is Suspended until it is resumed. Returns nil, with the
 * reason in the error, for a model the trainer cannot train or samples it cannot read. */
+ (nullable instancetype)charon_ml_taskForModelAtURL:(NSURL *)modelURL
                                        trainingData:(id<MLBatchProvider>)trainingData
                                    progressHandlers:(nullable MLUpdateProgressHandlers *)progressHandlers
                                               error:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END

#endif /* CHARON_ML_UPDATE_TASK_H */
