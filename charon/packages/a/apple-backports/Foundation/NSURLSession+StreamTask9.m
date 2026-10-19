#import <Foundation/Foundation.h>
#import <objc/message.h>

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
