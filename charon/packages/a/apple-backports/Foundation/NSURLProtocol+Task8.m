#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* A protocol that serves a session's task. The task is the request's owner: -canInitWithTask: asks
   the protocol the question it asks for a request, with the task's current request, and
   -initWithTask:cachedResponse:client: is -initWithRequest:cachedResponse:client: with the task kept
   beside it, so that the code a protocol runs can ask which task it is serving. */

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
