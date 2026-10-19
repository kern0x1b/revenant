#import <Foundation/Foundation.h>

@interface CharonOperationScheduler : NSObject
- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue owner:(NSOperationQueue *)owner;
@property (nonatomic, readonly) dispatch_queue_t dispatchQueue;
@property (nonatomic) BOOL suspended;
@property (nonatomic) NSInteger maxConcurrentOperationCount;
- (void)addOperation:(NSOperation *)operation;
- (NSArray *)operations;
- (NSUInteger)operationCount;
- (void)cancelAllOperations;
- (void)waitUntilAllOperationsAreFinished;
@end
