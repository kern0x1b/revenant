#ifndef CHARON_ML_UPDATE_TASK_H
#define CHARON_ML_UPDATE_TASK_H

#import <CoreML/CoreML.h>

NS_ASSUME_NONNULL_BEGIN

@interface MLTask (CharonMLUpdateTask)
- (instancetype)initForCharonML;
- (void)charon_ml_setState:(MLTaskState)state error:(nullable NSError *)error;
- (BOOL)charon_ml_isCancelling;
@end

@interface MLUpdateProgressHandlers (CharonMLUpdateTask)
- (MLUpdateProgressEvent)charon_ml_interestedEvents;
- (nullable void (^)(MLUpdateContext *))charon_ml_progressHandler;
- (void (^)(MLUpdateContext *))charon_ml_completionHandler;
@end

@interface MLModel (CharonMLUpdateTask)
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url
                                 configuration:(nullable MLModelConfiguration *)configuration
                                         error:(NSError * _Nullable * _Nullable)error;
@end

@interface MLUpdateContext (CharonMLUpdateContext)
- (instancetype)initForCharonMLWithTask:(MLUpdateTask *)task
                                 model:(MLModel *)model
                                 event:(MLUpdateProgressEvent)event
                               metrics:(NSDictionary *)metrics
                            parameters:(NSDictionary *)parameters;
@end

@interface MLUpdateTask (CharonMLUpdateTask)
+ (nullable instancetype)charon_ml_taskForModelAtURL:(NSURL *)modelURL
                                        trainingData:(id<MLBatchProvider>)trainingData
                                    progressHandlers:(nullable MLUpdateProgressHandlers *)progressHandlers
                                               error:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END

#endif
