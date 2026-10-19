#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
// NOT CharonMetal.h, and that is why this file can be measured on a host at all: that header reaches
// OpenGLES/EAGL.h, which is a DEVICE framework, so a case that #includes this file could not compile
// it. Nothing here needs it - the two descriptors hold values - and the queue, which does, is not here.
#import "CharonMetal26Types.h"


// THE TOP OF THE METAL 4 COMMAND CHAIN, and it is the first part of Metal 4 in this port that is NOT
// only a data holder: a queue is something an application asks the DEVICE for and then asks for command
// buffers, and this file carries the queue and the two descriptors that describe one.
//
// WHAT IS HERE, AND WHY IT IS ONLY THE TWO DESCRIPTORS AND THE ERROR DOMAIN. The queue itself, the two
// device factories that vend one and the capture scope over one are NOT here, and each has a measured
// reason:
//
//   * THE QUEUE IS AN EAGL OBJECT. It is a wrapper over the port's own CharonMetalQueue, which holds an
//     EAGL context over OpenGL ES 2.0, so no host case can compile or link it - OpenGLES/EAGL.h is a
//     device framework. That is a different wall from Apple's own, and it is why the two descriptors,
//     which hold only values, are in this file and the queue is not.
//   * -[MTLDevice newCommandQueueWithDescriptor:] RAISES on this SDK. Apple's own queue sends
//     -disableIOFencing to the descriptor and the SDK's own MTL4CommandQueueDescriptor does not
//     implement it, so the framework refuses itself: there is no Apple behaviour to copy for the
//     descriptor path even on a device.
//   * -[MTL4CommandQueue beginCommandBufferWithAllocator:] IS NOT IMPLEMENTED on Apple's own queue here,
//     so on this machine there is no live Metal 4 command buffer to compare against and nothing below it
//     either - the buffer, the encoder and the two encoders.
//
// All three are in facts/Metal/CommandChain26.md with the runs, and the rows for the queue and its
// factories are next, with the rest of the chain and one decision about how an EAGL-backed object is
// verified.

// THE ERROR DOMAIN, and its value is its own name - measured out of Apple's own framework with a
// nonsense name as the control, not assumed from the sibling domains in MTLError.h.
NSString *const MTL4CommandQueueErrorDomain = @"MTL4CommandQueueErrorDomain";

// THE TWO DESCRIPTORS, and every default is Apple's own, measured against a fresh object of Apple's
// class: both labels and both other members read NIL on a fresh descriptor.

// A dispatch_queue_t is a dispatch object and the descriptor's feedbackQueue is ASSIGNED, not retained,
// so the port keeps it exactly as the header says - as the caller's queue, with a comment saying so,
// because a port that retained it would keep a queue alive that Apple does not.
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

// THE HEADER SAYS `assign`, and that is what this is: the descriptor does not retain the queue, so a
// caller that passes one of its own does not have to keep it alive for the descriptor's sake and the
// descriptor does not keep it alive afterwards.
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
    // id<MTLLogState> IS FORWARD-DECLARED in this package, so it names no members and `logState.hash`
    // would not compile. The comparison goes through the object's own -isEqual: and -hash, which every
    // object has, and the pointer shortcut covers the both-nil case that -[nil isEqual:nil] gets wrong.
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
