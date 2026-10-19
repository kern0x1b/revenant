#import <Foundation/Foundation.h>

@implementation NSURLCache (RevenantDataTask)

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forDataTask:(NSURLSessionDataTask *)dataTask
{
    NSURLRequest *request = dataTask.currentRequest ?: dataTask.originalRequest;
    if (!request)
        return;
    [self storeCachedResponse:cachedResponse forRequest:request];
}

- (void)removeCachedResponseForDataTask:(NSURLSessionDataTask *)dataTask
{
    NSURLRequest *request = dataTask.currentRequest ?: dataTask.originalRequest;
    if (!request)
        return;
    [self removeCachedResponseForRequest:request];
}

- (void)getCachedResponseForDataTask:(NSURLSessionDataTask *)dataTask completionHandler:(void (^)(NSCachedURLResponse *))completionHandler
{
    NSURLRequest *request = dataTask.currentRequest ?: dataTask.originalRequest;
    completionHandler(request ? [self cachedResponseForRequest:request] : nil);
}

@end
