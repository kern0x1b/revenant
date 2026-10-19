#import <CoreML/CoreML.h>
#import "RevenantMLUpdateTask.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation MLUpdateTask (RevenantMLUpdateTaskiOS14)

+ (nullable instancetype)updateTaskForModelAtURL:(NSURL *)modelURL
                                    trainingData:(id<MLBatchProvider>)trainingData
                               completionHandler:(void (^)(MLUpdateContext * _Nonnull))completionHandler
                                           error:(NSError * _Nullable __autoreleasing *)error
{
    return [self updateTaskForModelAtURL:modelURL
                            trainingData:trainingData
                           configuration:nil
                       completionHandler:completionHandler
                                   error:error];
}

+ (nullable instancetype)updateTaskForModelAtURL:(NSURL *)modelURL
                                    trainingData:(id<MLBatchProvider>)trainingData
                                progressHandlers:(MLUpdateProgressHandlers *)progressHandlers
                                           error:(NSError * _Nullable __autoreleasing *)error
{
    return [self updateTaskForModelAtURL:modelURL
                            trainingData:trainingData
                           configuration:nil
                        progressHandlers:progressHandlers
                                   error:error];
}

@end
