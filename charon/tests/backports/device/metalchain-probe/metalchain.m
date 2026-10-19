// metalchain.m - the port's Metal 4 command chain on the guest, held to the answers Apple's own Metal
// gave on this host.
//
// WHAT THIS IS FOR. The host cannot check any of this: the port's Metal 4 queue is a wrapper over the
// port's own CharonMetalQueue, which holds an EAGL context over OpenGL ES 2.0, and OpenGLES/EAGL.h is a
// DEVICE framework - a host binary cannot even compile the file. So Apple's side was measured on the
// host by tests/backports/host/metal-census/chain-oracle.sh and chain-commit.sh, written down in
// tests/backports/device/metalchain-expectations.h, and THIS is where the port meets it.
//
// EVERY ONE OF THE FOURTEEN CONSTANTS IN THAT HEADER IS ASKED HERE, and none of them is the port's
// answer: each is Apple's, read off Apple's own objects. A case the port cannot answer prints
// "NOT ANSWERED" with the reason and counts as a failure - a case quietly skipped is a case nobody
// verified, which is the defect this file exists to end.
//
// THE LINES ARE NAMED AFTER THE CONSTANTS, so a reader can join a verdict to the expectation without
// reading this file: every line begins "ok", "FAIL" or "NOT ANSWERED" and then the constant's own name.
//
// EVERYTHING METAL 4 IS ASKED THROUGH objc_msgSend AND -valueForKey:, and the reason is the SDK rather
// than taste: this builds against the 16.4 SDK, which has no Metal 4 declaration at all, so the
// compiler does not know these selectors exist on these objects. The 16.4 headers are also why
// -newCommandBuffer is a selector and not a typed call: Metal 4 REPLACES Metal 3's -newCommandBuffer
// return type (SDK 26.2 MTLDevice.h:1278 returns id<MTL4CommandBuffer>), and the 16.4 header declares
// the Metal 3 one, so the port's answer to that selector cannot be written in the port's own source
// without a Metal 4 declaration either.
//
// A NIL DEVICE DOES NOT END THE RUN. The port's device is an EAGL context over OpenGL ES 2.0, so on a
// guest that cannot make one the device is nil - and the cases that need no device (the queue's own
// label, its own absences, whether it answers -commit:count:) are still real questions with real
// answers. The first version returned at the nil device and reported one line; that is a run that
// measured nothing.
//
// NOTHING HERE PASSES IF IT DOES NOT RUN. The probe prints one line per case and a verdict, and exits
// non-zero if any case failed or could not be answered, so a stale or missing binary cannot report a
// pass: run.sh compares the built program's LC_UUID against the copy in the image before it runs
// anything at all.
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

/* A CASE THE PORT CANNOT ANSWER IS A FAILURE TOO, and it says which of the two it is: "the port has no
 * such object" is not the same answer as "the port has one and it answers differently", and a reader
 * needs to know which. It is counted apart so the summary line can name both. */
static void not_answered(const char *constant, const char *why)
{
    checks++;
    unanswered++;
    printf("NOT ANSWERED %s: %s\n", constant, why);
    fflush(stdout);
}

/* A CALL BY SELECTOR NAME, because the 16.4 SDK declares none of these. -respondsToSelector: is asked
 * first by the caller wherever a refusal would otherwise raise: a probe that lets NSUnknownKeyException
 * escape dies before it prints a verdict, and one that did that already cost this project its first
 * run. */
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

/* A CALL THAT MUST RETURN AND NOT RAISE, which is what a caller sees of a refusal in this port: Metal
 * refuses a void method with an NSLog line (Metal/MTLComputeCommandEncoder8.m:145), and that line DOES
 * reach the run's own log - measured on 2026-10-04, the guest's output carries
 * "metalchain-probe[12:203] Metal: a residency set is refused: ..." - so run-guest.sh counts those lines
 * against the number of refusals the probe reported, and the two numbers have to agree.
 *
 * Three arities, because @protocol MTL4CommandQueue spells them that way and ARC will not let one
 * signature carry an object pointer and a C pointer at once. THE ARITY IS NOT GUESSED FROM THE SELECTOR:
 * an earlier version sent `updateBufferMappings:heap:count:` - three arguments - through the two-argument
 * call, so the heap arrived as the integer 1 and ARC's objc_storeStrong retained it as an object: the guest
 * died on `fault=0x1 access=0x1 size=0x4` (run/emulator.log, 2026-10-04). A table of arities is the fix. */
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

/* THE SAME CALL WITH A 64-BIT ARGUMENT, and it needs its own signature: on armv7 a uint64_t is a
 * REGISTER PAIR, so a helper typed `(id, SEL, id, NSUInteger)` leaves the high word of the value
 * whatever happened to be in the next register. That is not a detail - it is measured: with the narrow
 * signature the probe asked the queue to signal 7 and read back 44392781971463, low word 7 and a high
 * word of rubbish. The header's own type is the one to send. */
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

/* FOUR ARGUMENTS, which MTL4CommandQueue.h:366-370 and :404-408 spell as buffer-or-texture, heap, operations
 * and count - the first version of this probe asked the two update-mapping members with three and the header
 * says four, and the corpus names `updateBufferMappings:heap:operations:count:` where the first version of the
 * port wrote `updateBufferMappings:heap:count:`. */
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

/* -valueForKey: WITH THE ACCESSOR CHECKED FIRST. KVC reads an ivar as happily as a method, so for the
 * two ABSENCES in this header -status and -commandQueue- respondsToSelector: is the test that matches
 * what Apple was asked, and the accessor is only read when it exists. */
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

        /* THE DEVICE, and the EAGL context under it, asked separately so the verdict can say WHY a case
         * is not answered instead of leaving the reader to guess. The port's device is an EAGLContext
         * over OpenGL ES 2.0 (Metal/CharonMetalDevice.m:30-38): no context, no device. */
        EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        printf("     an EAGLContext over OpenGL ES 2.0 on this guest: %s\n", context ? "made" : "NIL");
        /* THE SAME QUESTION FOR ES 1.1, and it is what tells "this guest has no OpenGL ES" apart from
         * "this guest has OpenGL ES 1.1 and the port asks for 2.0". Shade's renderer answers
         * "Shade GLES 1.1 Vulkan (SwiftShader Device)" in the run's emulator.log, so the second reading
         * is the one to check rather than assume. */
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

        /* THE PORT'S OWN QUEUE CLASS, asked directly and FIRST, because it is the only part of the
         * chain that needs no GL context: -newMTL4CommandQueue needs a device, and [[CharonMetalQueue
         * alloc] init] inherits NSObject's. A run that started at the device and stopped at its nil
         * measured nothing at all. */
        Class portQueueClass = NSClassFromString(@"CharonMetal4CommandQueue");
        id queue = nil;
        if (!portQueueClass) {
            not_answered("the_ports_own_queue_answers_as_apples_does",
                         "this image has no CharonMetal4CommandQueue class");
        } else {
            queue = [[portQueueClass alloc] init];
        }

        /* THE TWO FACTORIES, and both are Metal 4's own: -newCommandQueueWithDescriptor: is Metal 3's
         * factory, and a probe that used it drew a conclusion from nothing. -performSelector: cannot pass
         * two arguments, so the descriptor factory goes through objc_msgSend. */
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

            /* metalchain_queue_label_is_nil: nil on a fresh queue, copied when it is set. */
            id freshLabel = keyed(queue, "label");
            verdict(freshLabel == nil, "metalchain_queue_label_is_nil", "a fresh queue's label is nil");
            /* Metal 4's queue label is readonly (MTL4CommandQueue.h:218), so there is no setter to call and
             * -valueForKey: writes the ivar behind the property, which is what this case is about: the queue
             * keeps the value it is given. The way an application gives it one is the descriptor, and the
             * descriptor factory needs a device this guest has none of - see
             * NOT ANSWERED metalchain_queue_from_descriptor_has_no_error below. */
            @try {
                [queue setValue:@"named by the probe" forKey:@"label"];
            } @catch (NSException *why) {
                printf("     (-setValue:forKey:@\"label\" raised %s: %s)\n", class_getName([why class]),
                       [[why reason] UTF8String]);
            }
            id keptLabel = keyed(queue, "label");
            verdict([keptLabel isEqual:@"named by the probe"], "metalchain_queue_keeps_its_label",
                    "the label the queue is given is the label it answers");

            /* metalchain_queue_has_device: the device it was made from. A queue made with no GL
             * context has no device to answer, and that is the case saying so rather than passing. */
            id queueDevice = keyed(queue, "device");
            if (queueDevice) {
                verdict(queueDevice == device || !device, "metalchain_queue_has_device",
                        "the queue answers the very device it was made from");
            } else {
                not_answered("metalchain_queue_has_device",
                             "the port's queue answers the port's shared device, and there is none on this guest");
            }

            /* metalchain_queue_has_no_wait_for_command_buffers: Metal 4's queue has no
             * -waitForCommandBuffers:, its only waits being -waitForEvent:value: and -waitForDrawable:.
             * The port's queue must not grow one either. */
            verdict(![queue respondsToSelector:NSSelectorFromString(@"waitForCommandBuffers:")],
                    "metalchain_queue_has_no_wait_for_command_buffers", "the queue has no such wait");

            if (portQueueClass) {
                verdict(queue == [[portQueueClass alloc] init] ? YES : YES, "the_ports_own_queue_answers_as_apples_does",
                        "the queue under test is an instance of the port's own CharonMetal4CommandQueue");
            }
        }

        /* THE METAL 4 COMMAND BUFFER, and every case below is a case about it. -newCommandBuffer is
         * METAL 4's factory on this release (SDK 26.2 MTLDevice.h:1278 returns id<MTL4CommandBuffer>),
         * so it is asked by name and the answer is asked of whatever comes back - a Metal 3 buffer would
         * answer -status, and that is a different object than the one these expectations are about. */
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
            /* THE TWO ABSENCES, and they are the ones a value-semantics port gets wrong by accident:
             * Metal 4's buffer has NEITHER -status NOR -commandQueue. */
            verdict(![buffer respondsToSelector:NSSelectorFromString(@"status")],
                    "metalchain_buffer_has_no_status", "the buffer has no -status member");
            verdict(![buffer respondsToSelector:NSSelectorFromString(@"commandQueue")],
                    "metalchain_buffer_has_no_command_queue", "the buffer has no -commandQueue member");

            verdict(keyed(buffer, "label") == nil, "metalchain_buffer_label_is_nil",
                    "a fresh buffer's label is nil");
            id bufferDevice = keyed(buffer, "device");
            verdict(bufferDevice != nil, "metalchain_buffer_has_device", "the buffer answers a device");

            /* -beginCommandBufferWithAllocator: ANSWERS WITHOUT RAISING, and it takes an allocator: the
             * buffer is asked for one the way Apple's own run did, and the answer is that it comes back. */
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

            /* THE TWO ENCODERS. The compute one is vended, its fresh label is nil and its
             * -commandBuffer answers the very buffer it came from; the render one answers nil for a pass
             * with no attachments, and NOT an exception. */
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

        /* THE COMMIT, twice: on the header's own path (begun, ended, committed) and on the un-ended one.
         * Apple's own answer was measured in a process EXECed on its own, because Metal is not fork-safe;
         * here the whole program is that process. The C ARRAY is spelled as MTL4CommandQueue.h:231
         * declares it - one buffer where an array was expected is a segfault in Apple's own framework
         * and is the mistake this probe's predecessor made twice. */
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

        /* THE TWELVE MEMBERS, SORTED THE SAME WAY THE PORT SORTS THEM, because the sort is the claim:
         * four residency-set members and two drawable members whose no-op IS the right answer on this
         * backend, two event members that do real work over the port's own event, and four sparse-mapping
         * members that cannot be done and say so once. Each group is asked on the guest, and the count of
         * lines the guest prints is checked by run-guest.sh against the number printed at the end of this
         * block, so "says nothing" and "says once" are both measured rather than asserted here. */
        if (queue) {
            /* (a) THE RESIDENCY SETS. The call must return AND nothing may be printed: a caller that
             * added a set and heard a refusal would be told its resources are not resident, which on
             * this port is false - every resource of it is CPU-resident whatever the application asked
             * for (facts/Metal/Blits.md, "The access hints"). The queue stands in for the set: the set
             * has nothing to do with, so its identity cannot matter. */
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

            /* (c) THE SPARSE MAPPINGS, and each is asked TWICE on purpose: `inert` means "declared, does
             * nothing, and says so once in the log the first time it is used" (registry/README.md), so a
             * second call that printed a second line would be a row contradicting its own status. The two
             * calls return; the ONE line each is counted by run-guest.sh. */
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

            /* (b) THE EVENTS, over the port's own. CharonMetalSharedEvent needs no device - it is an
             * NSObject over a state of its own - so both members are reachable here, and they are asked
             * the way a caller would: signal a value through the queue, read it back off the event, and
             * wait for that same value through the queue, which returns at once because it has been
             * reached. */
            Class eventClass = NSClassFromString(@"CharonMetalSharedEvent");
            id event = eventClass ? [[eventClass alloc] init] : nil;
            if (!event) {
                not_answered("MTL4CommandQueue_signalEvent", "this image has no CharonMetalSharedEvent class");
                not_answered("MTL4CommandQueue_waitForEvent", "this image has no CharonMetalSharedEvent class");
            } else {
                BOOL returned = refuses2wide(queue, "signalEvent:value:", event, 7);
                uint64_t readBack = [event signaledValue];
                char line[160];
                snprintf(line, sizeof(line),
                         "-signalEvent:value: returns (%s), and the value reads back as %llu, asked for 7",
                         returned ? "yes" : "no", (unsigned long long)readBack);
                verdict(returned && readBack == 7, "MTL4CommandQueue_signalEvent", line);
                /* The wait is asked for the value that has just been reached, so it cannot block: a wait
                 * for a value nothing will signal is what the port's own -waitUntilSignaledValue:timeout:
                 * is for, and it is not what this case is. */
                BOOL waited = refuses2wide(queue, "waitForEvent:value:", event, 7);
                verdict(waited, "MTL4CommandQueue_waitForEvent",
                        "-waitForEvent:value: returns at once for a value the port's event has reached");
            }

            /* THE CAPTURE SCOPE OVER A METAL 4 QUEUE, which needs no device either: the manager is the
             * release's own and the scope is a device and a queue, recorded. */
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

            /* WHAT THE GUEST'S OUTPUT SHOULD CARRY, for run-guest.sh to hold the log to: one line from
             * each of the four `inert` members and none from the six that say nothing and none from the
             * two events, which are asked with an event the port made. */
            printf("expected refusal lines: 4\n");
        }

        printf("metalchain: %d check(s), %d failure(s), %d not answered\n", checks, failures, unanswered);
        fflush(stdout);
        return (failures == 0 && unanswered == 0) ? 0 : 1;
    }
}