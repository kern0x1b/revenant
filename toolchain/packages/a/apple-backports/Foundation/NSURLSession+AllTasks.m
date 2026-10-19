#import <Foundation/Foundation.h>

@implementation NSURLSession (CharonAllTasks)

- (void)getAllTasksWithCompletionHandler:(void (^)(NSArray *))completionHandler
{
    void (^handler)(NSArray *) = [completionHandler copy];
    [self getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        NSMutableArray *tasks = [NSMutableArray arrayWithArray:dataTasks];
        [tasks addObjectsFromArray:uploadTasks];
        [tasks addObjectsFromArray:downloadTasks];
        [tasks sortUsingComparator:^NSComparisonResult(NSURLSessionTask *a, NSURLSessionTask *b) {
            return a.taskIdentifier < b.taskIdentifier ? NSOrderedAscending : a.taskIdentifier > b.taskIdentifier ? NSOrderedDescending : NSOrderedSame;
        }];
        if (handler)
            handler(tasks);
    }];
}

@end
