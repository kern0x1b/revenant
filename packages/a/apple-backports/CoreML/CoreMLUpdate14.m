// The two constructors of MLUpdateTask that the 16.4 headers annotate as API_AVAILABLE(macos(11.0), ios(14.0)):
// updateTaskForModelAtURL:trainingData:completionHandler:error: (MLUpdateTask.h:30-33) and
// updateTaskForModelAtURL:trainingData:progressHandlers:error: (:43-46). They take no configuration. Both are the
// constructors of CoreMLUpdate13.m with the configuration left out, so the training is the one that file runs.
// The two constructors that take a configuration are iOS 13 API (MLUpdateTask.h:23 and :36 carry no annotation of
// their own, so they inherit the class's 13.0), and they are in CoreMLUpdate13.m.

#import <CoreML/CoreML.h>
#import "CharonMLUpdateTask.h"

// These two are declared on MLUpdateTask in the framework's header, and the category implements them on purpose, so
// that the iOS 14 constructors live in this file and not in the iOS 13 one. Clang's warning that the primary class
// will also implement them is the cost of that placement, and it is silenced here alone.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation MLUpdateTask (CharonMLUpdateTaskiOS14)

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
