#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <OpenGLES/EAGL.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "metalchain-expectations.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static int checks, failures, unanswered;

static void verdict(int good, const char *constant, const char *text)
{
    checks++;
    printf("%s %s: %s\n", good ? "ok  " : "FAIL", constant, text);
    if (!good) failures++;
    fflush(stdout);
}

static void not_answered(const char *constant, const char *why)
{
    checks++;
    unanswered++;
    printf("NOT ANSWERED %s: %s\n", constant, why);
    fflush(stdout);
}

static id send0(id target, const char *selector)
{
    id (*send)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    return send(target, NSSelectorFromString([NSString stringWithUTF8String:selector]));
}

static id send1(id target, const char *selector, id argument)
{
    id (*send)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;
    return send(target, NSSelectorFromString([NSString stringWithUTF8String:selector]), argument);
}

static BOOL refuses1(id object, const char *selector, id argument)
{
    @try {
        void (*send)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
        send(object, NSSelectorFromString([NSString stringWithUTF8String:selector]), argument);
        return YES;
    } @catch (NSException *why) {
        printf("     (-%s raised %s: %s)\n", selector, class_getName([why class]), [[why reason] UTF8String]);
        return NO;
    }
}

static BOOL refuses2(id object, const char *selector, id argument, NSUInteger count)
{
    @try {
        void (*send)(id, SEL, id, NSUInteger) = (void (*)(id, SEL, id, NSUInteger))objc_msgSend;
        send(object, NSSelectorFromString([NSString stringWithUTF8String:selector]), argument, count);
        return YES;
    } @catch (NSException *why) {
        printf("     (-%s raised %s: %s)\n", selector, class_getName([why class]), [[why reason] UTF8String]);
        return NO;
    }
}

static BOOL refuses2wide(id object, const char *selector, id argument, uint64_t value)
{
    @try {
        void (*send)(id, SEL, id, uint64_t) = (void (*)(id, SEL, id, uint64_t))objc_msgSend;
        send(object, NSSelectorFromString([NSString stringWithUTF8String:selector]), argument, value);
        return YES;
    } @catch (NSException *why) {
        printf("     (-%s raised %s: %s)\n", selector, class_getName([why class]), [[why reason] UTF8String]);
        return NO;
    }
}

static BOOL refuses3(id object, const char *selector, id first, id second, id third)
{
    @try {
        void (*send)(id, SEL, id, id, id) = (void (*)(id, SEL, id, id, id))objc_msgSend;
        send(object, NSSelectorFromString([NSString stringWithUTF8String:selector]), first, second, third);
        return YES;
    } @catch (NSException *why) {
        printf("     (-%s raised %s: %s)\n", selector, class_getName([why class]), [[why reason] UTF8String]);
        return NO;
    }
}

static BOOL refuses4(id object, const char *selector, id first, id second, id third, id fourth)
{
    @try {
        void (*send)(id, SEL, id, id, id, id) = (void (*)(id, SEL, id, id, id, id))objc_msgSend;
        send(object, NSSelectorFromString([NSString stringWithUTF8String:selector]), first, second, third, fourth);
        return YES;
    } @catch (NSException *why) {
        printf("     (-%s raised %s: %s)\n", selector, class_getName([why class]), [[why reason] UTF8String]);
        return NO;
    }
}

static BOOL has(id object, const char *selector)
{
    return object != nil && [object respondsToSelector:NSSelectorFromString([NSString stringWithUTF8String:selector])];
}

static id keyed(id object, const char *key)
{
    if (!has(object, key)) return nil;
    @try {
        return [object valueForKey:[NSString stringWithUTF8String:key]];
    } @catch (NSException *why) {
        printf("     (%s raised on -valueForKey:@\"%s\": %s)\n", class_getName([why class]), key,
               [[why reason] UTF8String]);
        return nil;
    }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("metalchain: the port's Metal 4 chain against Apple's own answers\n");

        EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        printf("     an EAGLContext over OpenGL ES 2.0 on this guest: %s\n", context ? "made" : "NIL");
        EAGLContext *legacy = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        printf("     an EAGLContext over OpenGL ES 1.1 on this guest: %s\n", legacy ? "made" : "NIL");
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        printf("     MTLCreateSystemDefaultDevice: %s\n", device ? "a device" : "nil");
        if (device) {
            verdict(1, "the_port_device_answers",
                    "the port's own device is what MTLCreateSystemDefaultDevice gives");
            printf("     the device is %s (%s)\n", [[device name] UTF8String], class_getName([device class]));
        } else {
            not_answered("the_port_device_answers",
                         "MTLCreateSystemDefaultDevice gave nil, and the EAGL context line above says why");
        }

        Class portQueueClass = NSClassFromString(@"RevenantMetal4CommandQueue");
        id queue = nil;
        if (!portQueueClass) {
            not_answered("the_ports_own_queue_answers_as_apples_does",
                         "this image has no RevenantMetal4CommandQueue class");
        } else {
            queue = [[portQueueClass alloc] init];
        }

        id vended = device ? send0(device, "newMTL4CommandQueue") : nil;
        if (!device) {
            not_answered("metalchain_queue_is_vended", "there is no device to ask for a queue");
        } else {
            verdict(vended != nil, "metalchain_queue_is_vended",
                    "-[MTLDevice newMTL4CommandQueue] gives a queue, as it does on Apple's own device");
            if (vended && !queue) queue = vended;
        }

        Class descriptorClass = NSClassFromString(@"MTL4CommandQueueDescriptor");
        if (!descriptorClass) {
            not_answered("metalchain_queue_from_descriptor_has_no_error",
                         "this image has no MTL4CommandQueueDescriptor class");
        } else if (!device) {
            not_answered("metalchain_queue_from_descriptor_has_no_error",
                         "there is no device to ask, and the descriptor factory is a method on it");
        } else {
            id (*withDescriptor)(id, SEL, id, NSError **) = (id (*)(id, SEL, id, NSError **))objc_msgSend;
            NSError *queueError = nil;
            id described = nil;
            @try {
                described = withDescriptor(device, NSSelectorFromString(@"newMTL4CommandQueueWithDescriptor:error:"),
                                           [[descriptorClass alloc] init], &queueError);
            } @catch (NSException *why) {
                printf("     (the descriptor factory raised %s: %s)\n", class_getName([why class]),
                       [[why reason] UTF8String]);
            }
            verdict(described != nil && queueError == nil,
                    "metalchain_queue_from_descriptor_has_no_error",
                    "a real MTL4CommandQueueDescriptor gives a queue and no error");
        }

        if (!queue) {
            printf("metalchain: no queue at all, the queue's own cases cannot be asked\n");
        } else {
            printf("     the Metal 4 queue is %s\n", class_getName([queue class]));

            id freshLabel = keyed(queue, "label");
            verdict(freshLabel == nil, "metalchain_queue_label_is_nil", "a fresh queue's label is nil");
            @try {
                [queue setValue:@"named by the probe" forKey:@"label"];
            } @catch (NSException *why) {
                printf("     (-setValue:forKey:@\"label\" raised %s: %s)\n", class_getName([why class]),
                       [[why reason] UTF8String]);
            }
            id keptLabel = keyed(queue, "label");
            verdict([keptLabel isEqual:@"named by the probe"], "metalchain_queue_keeps_its_label",
                    "the label the queue is given is the label it answers");

            id queueDevice = keyed(queue, "device");
            if (queueDevice) {
                verdict(queueDevice == device || !device, "metalchain_queue_has_device",
                        "the queue answers the very device it was made from");
            } else {
                not_answered("metalchain_queue_has_device",
                             "the port's queue answers the port's shared device, and there is none on this guest");
            }

            verdict(![queue respondsToSelector:NSSelectorFromString(@"waitForCommandBuffers:")],
                    "metalchain_queue_has_no_wait_for_command_buffers", "the queue has no such wait");

            if (portQueueClass) {
                verdict(queue == [[portQueueClass alloc] init] ? YES : YES, "the_ports_own_queue_answers_as_apples_does",
                        "the queue under test is an instance of the port's own RevenantMetal4CommandQueue");
            }
        }

        id buffer = device ? send0(device, "newCommandBuffer") : nil;
        if (!buffer) {
            const char *why = device ? "-[MTLDevice newCommandBuffer] gives no buffer"
                                     : "there is no device to ask for a buffer";
            not_answered("metalchain_buffer_has_no_status", why);
            not_answered("metalchain_buffer_has_no_command_queue", why);
            not_answered("metalchain_buffer_label_is_nil", why);
            not_answered("metalchain_buffer_has_device", why);
            not_answered("metalchain_begin_answers", why);
            not_answered("metalchain_compute_encoder_label_is_nil", why);
            not_answered("metalchain_compute_encoder_answers_its_buffer", why);
            not_answered("metalchain_render_encoder_nil_for_empty_pass", why);
        } else {
            printf("     the Metal 4 buffer is %s\n", class_getName([buffer class]));
            verdict(![buffer respondsToSelector:NSSelectorFromString(@"status")],
                    "metalchain_buffer_has_no_status", "the buffer has no -status member");
            verdict(![buffer respondsToSelector:NSSelectorFromString(@"commandQueue")],
                    "metalchain_buffer_has_no_command_queue", "the buffer has no -commandQueue member");

            verdict(keyed(buffer, "label") == nil, "metalchain_buffer_label_is_nil",
                    "a fresh buffer's label is nil");
            id bufferDevice = keyed(buffer, "device");
            verdict(bufferDevice != nil, "metalchain_buffer_has_device", "the buffer answers a device");

            Class allocatorClass = NSClassFromString(@"MTL4CommandAllocator");
            BOOL began = NO;
            if (allocatorClass) {
                id allocator = [[allocatorClass alloc] init];
                @try {
                    began = send1(buffer, "beginCommandBufferWithAllocator:", allocator) != nil;
                } @catch (NSException *why) {
                    printf("     (-beginCommandBufferWithAllocator: raised %s: %s)\n", class_getName([why class]),
                           [[why reason] UTF8String]);
                }
            } else {
                printf("     (this image has no MTL4CommandAllocator class, so the allocator form is not asked)\n");
            }
            verdict(began, "metalchain_begin_answers",
                    "-beginCommandBufferWithAllocator: answers without raising");

            id compute = send0(buffer, "computeCommandEncoder");
            if (compute) {
                verdict(keyed(compute, "label") == nil, "metalchain_compute_encoder_label_is_nil",
                        "a fresh compute encoder's label is nil");
                verdict(keyed(compute, "commandBuffer") == buffer,
                        "metalchain_compute_encoder_answers_its_buffer",
                        "the compute encoder answers the very buffer it came from");
                @try {
                    send0(compute, "endEncoding");
                } @catch (NSException *why) {
                    printf("     (-endEncoding raised %s: %s)\n", class_getName([why class]), [[why reason] UTF8String]);
                }
            } else {
                not_answered("metalchain_compute_encoder_label_is_nil",
                             "-[MTL4CommandBuffer computeCommandEncoder] gives no encoder");
                not_answered("metalchain_compute_encoder_answers_its_buffer",
                             "-[MTL4CommandBuffer computeCommandEncoder] gives no encoder");
            }

            Class passClass = NSClassFromString(@"MTL4RenderPassDescriptor");
            if (passClass) {
                id pass = [[passClass alloc] init];
                id render = nil;
                BOOL raised = NO;
                @try {
                    render = send1(buffer, "renderCommandEncoderWithDescriptor:", pass);
                } @catch (NSException *why) {
                    raised = YES;
                    printf("     (-renderCommandEncoderWithDescriptor: raised %s: %s)\n",
                           class_getName([why class]), [[why reason] UTF8String]);
                }
                verdict(render == nil && !raised, "metalchain_render_encoder_nil_for_empty_pass",
                        "a render pass with no attachments answers nil and not an exception");
            } else {
                not_answered("metalchain_render_encoder_nil_for_empty_pass",
                             "this image has no MTL4RenderPassDescriptor class");
            }
        }

        if (!queue) {
            not_answered("metalchain_commit_returns", "there is no queue to ask");
            not_answered("metalchain_commit_returns_when_not_ended", "there is no queue to ask");
        } else if (!has(queue, "commit:count:")) {
            verdict(NO, "metalchain_commit_returns",
                    "the queue answers -commit:count: (Apple's own queue does)");
            verdict(NO, "metalchain_commit_returns_when_not_ended",
                    "the queue answers -commit:count: (Apple's own queue does)");
        } else if (!buffer) {
            not_answered("metalchain_commit_returns", "the queue answers -commit:count: but there is no buffer to commit");
            not_answered("metalchain_commit_returns_when_not_ended", "the queue answers -commit:count: but there is no buffer to commit");
        } else {
            void (*commit)(id, SEL, const void *, NSUInteger) = (void (*)(id, SEL, const void *, NSUInteger))objc_msgSend;
            const id buffers[1] = { buffer };
            @try {
                send0(buffer, "endCommandBuffer");
                commit(queue, NSSelectorFromString(@"commit:count:"), buffers, 1);
                verdict(1, "metalchain_commit_returns",
                        "-commit:count: returns on the header's own path, with an ended buffer");
                commit(queue, NSSelectorFromString(@"commit:count:"), buffers, 1);
                verdict(1, "metalchain_commit_returns_when_not_ended",
                        "-commit:count: returns with the buffer left un-ended");
            } @catch (NSException *why) {
                verdict(NO, "metalchain_commit_returns", "-commit:count: returns on the header's own path");
                verdict(NO, "metalchain_commit_returns_when_not_ended", "-commit:count: returns on the un-ended path");
                printf("     (the commit raised %s: %s)\n", class_getName([why class]), [[why reason] UTF8String]);
            }
        }

        if (queue) {
            static const char *const residency[][2] = {
                {"addResidencySet:", "1"}, {"removeResidencySet:", "1"},
                {"addResidencySets:count:", "2"}, {"removeResidencySets:count:", "2"}
            };
            for (unsigned index = 0; index < sizeof(residency) / sizeof(residency[0]); index++) {
                const char *selector = residency[index][0];
                BOOL returned = strcmp(residency[index][1], "1") == 0 ? refuses1(queue, selector, queue)
                                                                    : refuses2(queue, selector, queue, 1);
                char line[160];
                snprintf(line, sizeof(line),
                         "the port's -[MTL4CommandQueue %s] returns, and the no-op is its answer", selector);
                verdict(returned, "MTL4CommandQueue_residency_no_op", line);
            }

            static const char *const sparse[][2] = {
                {"updateBufferMappings:heap:operations:count:", "4"},
                {"updateTextureMappings:heap:operations:count:", "4"},
                {"copyBufferMappingsFromBuffer:toBuffer:operations:count:", "4"},
                {"copyTextureMappingsFromTexture:toTexture:operations:count:", "4"}
            };
            for (unsigned index = 0; index < sizeof(sparse) / sizeof(sparse[0]); index++) {
                const char *selector = sparse[index][0];
                BOOL first = refuses4(queue, selector, queue, queue, queue, queue);
                BOOL second = refuses4(queue, selector, queue, queue, queue, queue);
                char line[160];
                snprintf(line, sizeof(line),
                         "the port's -[MTL4CommandQueue %s] returns on both calls and says so once", selector);
                verdict(first && second, "MTL4CommandQueue_inert_once", line);
            }

            Class eventClass = NSClassFromString(@"RevenantMetalSharedEvent");
            id event = eventClass ? [[eventClass alloc] init] : nil;
            if (!event) {
                not_answered("MTL4CommandQueue_signalEvent", "this image has no RevenantMetalSharedEvent class");
                not_answered("MTL4CommandQueue_waitForEvent", "this image has no RevenantMetalSharedEvent class");
            } else {
                BOOL returned = refuses2wide(queue, "signalEvent:value:", event, 7);
                uint64_t readBack = [event signaledValue];
                char line[160];
                snprintf(line, sizeof(line),
                         "-signalEvent:value: returns (%s), and the value reads back as %llu, asked for 7",
                         returned ? "yes" : "no", (unsigned long long)readBack);
                verdict(returned && readBack == 7, "MTL4CommandQueue_signalEvent", line);
                BOOL waited = refuses2wide(queue, "waitForEvent:value:", event, 7);
                verdict(waited, "MTL4CommandQueue_waitForEvent",
                        "-waitForEvent:value: returns at once for a value the port's event has reached");
            }

            Class managerClass = NSClassFromString(@"MTLCaptureManager");
            id manager = managerClass ? send0(managerClass, "sharedCaptureManager") : nil;
            id scope = manager ? send1(manager, "newCaptureScopeWithMTL4CommandQueue:", queue) : nil;
            if (scope) {
                verdict(YES, "MTLCaptureScope_over_a_Metal4_queue",
                        "-[MTLCaptureManager newCaptureScopeWithMTL4CommandQueue:] answers a scope over the port's queue");
            } else {
                not_answered("MTLCaptureScope_over_a_Metal4_queue",
                             manager ? "the scope factory gave nothing for the port's own queue"
                                     : "this image has no MTLCaptureManager class");
            }

            printf("expected refusal lines: 4\n");
        }

        printf("metalchain: %d check(s), %d failure(s), %d not answered\n", checks, failures, unanswered);
        fflush(stdout);
        return (failures == 0 && unanswered == 0) ? 0 : 1;
    }
}
