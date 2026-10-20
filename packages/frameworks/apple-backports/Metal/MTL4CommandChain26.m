#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import "RevenantMetal26Types.h"


NSString *const MTL4CommandQueueErrorDomain = @"MTL4CommandQueueErrorDomain";

@implementation MTL4CommandQueueDescriptor {
    NSString *_label;
    __unsafe_unretained dispatch_queue_t _feedbackQueue;
}

@synthesize label = _label;
@synthesize feedbackQueue = _feedbackQueue;

- (void)setLabel:(NSString *)label
{
    _label = [label copy];
}

- (void)setFeedbackQueue:(dispatch_queue_t)feedbackQueue
{
    _feedbackQueue = feedbackQueue;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4CommandQueueDescriptor *copy = [[MTL4CommandQueueDescriptor alloc] init];
    copy.label = _label;
    copy.feedbackQueue = _feedbackQueue;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4CommandQueueDescriptor class]]) return NO;
    MTL4CommandQueueDescriptor *theirs = object;
    if (self.label != theirs.label && ![self.label isEqual:theirs.label]) return NO;
    if (self.feedbackQueue != theirs.feedbackQueue) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[self.label hash];
    hash = hash * 31u + (uint32_t)self.feedbackQueue;
    return hash;
}

@end

@implementation MTL4CommandBufferOptions {
    id<MTLLogState> _logState;
}

@synthesize logState = _logState;

- (void)setLogState:(id<MTLLogState>)logState
{
    _logState = logState;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4CommandBufferOptions *copy = [[MTL4CommandBufferOptions alloc] init];
    copy.logState = _logState;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4CommandBufferOptions class]]) return NO;
    MTL4CommandBufferOptions *theirs = object;
    if (self.logState != theirs.logState && ![(id)self.logState isEqual:(id)theirs.logState]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)[(id)self.logState hash];
    return hash;
}

@end
