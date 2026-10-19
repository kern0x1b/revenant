#import <Foundation/Foundation.h>

/* The cache's three data-task methods, which are the request's own methods with the task's request.
   A task's currentRequest is what it is sending now and its originalRequest is what it started with;
   the cache is the release's own, so what it stores and when it drops it are the release's answers
   (measured on the host: a stored response reads back, -removeCachedResponseForRequest: takes it
   away, and -removeCachedResponsesSinceDate: keeps a response that is newer than the date). */

@implementation NSURLCache (CharonDataTask)

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
