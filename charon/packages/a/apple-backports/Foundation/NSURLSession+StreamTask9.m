#import <Foundation/Foundation.h>
#import <objc/message.h>

/* The two factories that make a stream task. The task is the port's own class (iOS 6 has no
   NSURLSessionStreamTask), it opens the release's own stream pair when it is resumed, and it drives
   the transfer itself.

   One divergence, written down rather than hidden: a stream task made here is not in the session's
   -getTasksWithCompletionHandler: list, because the port's session keeps that list in its own storage
   and this file is a category beside it. -getTasksWithCompletionHandler: therefore answers the data,
   upload and download tasks and no stream task; facts/Foundation/NSURLSessionStreamTask.md says so. */

@interface NSURLSessionStreamTask (CharonConstruction)
- (instancetype)initWithSession:(NSURLSession *)session hostName:(NSString *)hostName port:(NSInteger)port;
@end

@implementation NSURLSession (CharonStreamTask)

- (NSURLSessionStreamTask *)streamTaskWithHostName:(NSString *)hostname port:(NSInteger)port
{
    NSURLSessionStreamTask *task = [[NSURLSessionStreamTask alloc] initWithSession:self hostName:hostname port:port];
    return task;
}

- (NSURLSessionStreamTask *)streamTaskWithNetService:(NSNetService *)service
{
    NSString *host = service.name;
    if (!host.length)
        host = @"localhost";
    return [self streamTaskWithHostName:host port:service.port];
}

@end
