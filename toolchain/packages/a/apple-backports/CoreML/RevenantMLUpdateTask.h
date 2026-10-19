#ifndef REVENANT_ML_UPDATE_TASK_H
#define REVENANT_ML_UPDATE_TASK_H

#import <CoreML/CoreML.h>

NS_ASSUME_NONNULL_BEGIN

@interface MLTask (RevenantMLUpdateTask)
- (instancetype)initForRevenantML;
- (void)revenant_ml_setState:(MLTaskState)state error:(nullable NSError *)error;
- (BOOL)revenant_ml_isCancelling;
@end

@interface MLUpdateProgressHandlers (RevenantMLUpdateTask)
- (MLUpdateProgressEvent)revenant_ml_interestedEvents;
- (nullable void (^)(MLUpdateContext *))revenant_ml_progressHandler;
- (void (^)(MLUpdateContext *))revenant_ml_completionHandler;
@end

@interface MLModel (RevenantMLUpdateTask)
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url
                                 configuration:(nullable MLModelConfiguration *)configuration
                                         error:(NSError * _Nullable * _Nullable)error;
@end

@interface MLUpdateContext (RevenantMLUpdateContext)
- (instancetype)initForRevenantMLWithTask:(MLUpdateTask *)task
                                 model:(MLModel *)model
                                 event:(MLUpdateProgressEvent)event
                               metrics:(NSDictionary *)metrics
                            parameters:(NSDictionary *)parameters;
@end

@interface MLUpdateTask (RevenantMLUpdateTask)
+ (nullable instancetype)revenant_ml_taskForModelAtURL:(NSURL *)modelURL
                                        trainingData:(id<MLBatchProvider>)trainingData
                                    progressHandlers:(nullable MLUpdateProgressHandlers *)progressHandlers
                                               error:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END

#endif
