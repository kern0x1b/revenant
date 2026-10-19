#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char CharonProtocolTaskKey;

@implementation NSURLProtocol (CharonTask)

+ (BOOL)canInitWithTask:(NSURLSessionTask *)task
{
    NSURLRequest *request = task.currentRequest ?: task.originalRequest;
    return request ? [self canInitWithRequest:request] : NO;
}

- (instancetype)initWithTask:(NSURLSessionTask *)task
             cachedResponse:(NSCachedURLResponse *)cachedResponse
                     client:(id<NSURLProtocolClient>)client
{
    NSURLRequest *request = task.currentRequest ?: task.originalRequest;
    self = [self initWithRequest:request cachedResponse:cachedResponse client:client];
    if (self)
        objc_setAssociatedObject(self, &CharonProtocolTaskKey, task, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (NSURLSessionTask *)task
{
    return objc_getAssociatedObject(self, &CharonProtocolTaskKey);
}

@end
