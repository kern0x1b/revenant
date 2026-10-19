/* chain-oracle.m - the LIVE Metal 4 command chain on this machine, asked with the selectors the 26.2
 * headers actually declare.
 *
 * This is the oracle the port's chain will be built against. Every call below goes through the runtime,
 * because the port's build SDK has no Metal 4 declaration at all and this file has to compile against
 * whatever SDK the host has; the selectors are spelled exactly as MTLDevice.h:1240, :1271, :1278 and
 * MTL4CommandBuffer.h:71, :95, :103 name them, and each line records which header line it came from.
 *
 * A PREVIOUS PROBE OF MINE GOT FOUR OF THESE WRONG and the answers it drew from them were wrong with it:
 * it called -newCommandQueueWithDescriptor:, which is METAL 3's factory (MTL4's is
 * -newMTL4CommandQueueWithDescriptor:error:, MTLDevice.h:1271), and it sent -beginCommandBufferWithAllocator:
 * to a QUEUE, when that method belongs to the command buffer (MTL4CommandBuffer.h:71). Both are retracted
 * in facts/Metal/CommandChain26.md; this file is the corrected measurement.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/message.h>

static id send(id target, NSString *name)
{
    SEL selector = NSSelectorFromString(name);
    if (![target respondsToSelector:selector]) {
        printf("   %-46s DOES NOT EXIST on %s\n", [name UTF8String],
               [NSStringFromClass([(id)target class]) UTF8String]);
        return nil;
    }
    id (*plain)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    return plain(target, selector);
}

static id send1(id target, NSString *name, id first)
{
    SEL selector = NSSelectorFromString(name);
    if (![target respondsToSelector:selector]) {
        printf("   %-46s DOES NOT EXIST on %s\n", [name UTF8String],
               [NSStringFromClass([(id)target class]) UTF8String]);
        return nil;
    }
    id (*one)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;
    return one(target, selector, first);
}

// NO `?:` ON A MESSAGE SEND ANYWHERE IN THIS FILE. It is a parse error inside an argument list - the
// first version had four of them and the compiler named all four - so every optional answer goes
// through these two.
static NSString *text(id object) { return object ? [object description] : nil; }
static const char *utf8(NSString *string) { return string ? [string UTF8String] : "(nil)"; }

// THE CLASS, NEVER THE ADDRESS. Apple's -description carries the object's pointer, so a table built from
// it differs on every run and a `git diff` on the committed table is always dirty - which is the one
// thing a table in a repository must not be.
static NSString *describe(id object)
{
    if (!object) return @"(nil)";
    return [NSString stringWithFormat:@"<%s>", [NSStringFromClass([(id)object class]) UTF8String]];
}

static void member(id object, NSString *key, NSString *name)
{
    if (!object) { printf("   %-34s -> (no object)\n", [name UTF8String]); return; }
    if (![object respondsToSelector:NSSelectorFromString(key)]) {
        printf("   %-34s -> not a member of %s\n", [name UTF8String],
               [NSStringFromClass([(id)object class]) UTF8String]);
        return;
    }
    id value = [object respondsToSelector:NSSelectorFromString(key)] ? [object valueForKey:key] : nil;
    /* A member that is an object prints as its CLASS here too, for the same reason. */
    const char *shown = (value && [value isKindOfClass:[NSObject class]] &&
                         ![value isKindOfClass:[NSValue class]])
        ? [describe(value) UTF8String] : utf8(text(value));
    printf("   %-34s -> %s\n", [name UTF8String], shown);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        printf("the device: %s\n", utf8(text(device.name)));
        printf("ZZZNoSuchNameCharonR16 -> %s\n\n",
               NSClassFromString(@"ZZZNoSuchNameCharonR16") ? "FOUND (wrong)" : "nil (right)");

        printf("MTL4CommandQueue, both ways the 26.2 header declares them\n");
        id plainQueue = send(device, @"newMTL4CommandQueue");
        printf("   newMTL4CommandQueue -> %s\n", [describe(plainQueue) UTF8String]);
        if (plainQueue) { member(plainQueue, @"label", @"a fresh queue's label"); member(plainQueue, @"device", @"its device"); }
        Class queueDescriptor = NSClassFromString(@"MTL4CommandQueueDescriptor");
        id described = [[queueDescriptor alloc] init];
        id (*withDescriptor)(id, SEL, id, NSError **) = (id (*)(id, SEL, id, NSError **))objc_msgSend;
        NSError *queueError = nil;
        @try {
            id describedQueue = withDescriptor(device, NSSelectorFromString(@"newMTL4CommandQueueWithDescriptor:error:"),
                                               described, &queueError);
            printf("   newMTL4CommandQueueWithDescriptor:error: (a REAL descriptor) -> %s, error %s\n",
                   describedQueue ? "a queue" : "nil", utf8(text(queueError)));
        } @catch (NSException *why) {
            printf("   newMTL4CommandQueueWithDescriptor:error: RAISED %s: %s\n",
                   [[why name] UTF8String], [[why reason] UTF8String]);
        }

        printf("\nMTL4CommandAllocator, MTLDevice.h:1240\n");
        id allocator = send(device, @"newCommandAllocator");
        printf("   newCommandAllocator -> %s\n", [describe(allocator) UTF8String]);
        if (allocator) { member(allocator, @"label", @"label"); member(allocator, @"device", @"device"); }

        printf("\nMTL4CommandBuffer, MTLDevice.h:1278\n");
        id buffer = send(device, @"newCommandBuffer");
        printf("   newCommandBuffer -> %s\n", [describe(buffer) UTF8String]);
        if (!buffer) { printf("   NO LIVE BUFFER: the chain stops here on this machine\n"); return 0; }
        member(buffer, @"label", @"a fresh buffer's label");
        member(buffer, @"device", @"device");
        member(buffer, @"commandQueue", @"commandQueue");
        member(buffer, @"status", @"status before begin");

        printf("\nbeginCommandBufferWithAllocator:, MTL4CommandBuffer.h:71\n");
        @try {
            void (*begin)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
            begin(buffer, NSSelectorFromString(@"beginCommandBufferWithAllocator:"), allocator);
            printf("   beginCommandBufferWithAllocator: answered without raising\n");
        } @catch (NSException *why) {
            printf("   RAISED %s: %s\n", [[why name] UTF8String], [[why reason] UTF8String]);
        }
        member(buffer, @"status", @"status after begin");

        printf("\nthe two encoders\n");
        id renderEncoder = nil, computeEncoder = nil;
        Class passDescriptor = NSClassFromString(@"MTL4RenderPassDescriptor");
        if (passDescriptor) {
            @try {
                renderEncoder = send1(buffer, @"renderCommandEncoderWithDescriptor:", [[passDescriptor alloc] init]);
                printf("   renderCommandEncoderWithDescriptor: -> %s\n", [describe(renderEncoder) UTF8String]);
            } @catch (NSException *why) {
                printf("   renderCommandEncoderWithDescriptor: RAISED %s: %s\n",
                       [[why name] UTF8String], [[why reason] UTF8String]);
            }
        } else printf("   MTL4RenderPassDescriptor -> nil\n");
        @try {
            computeEncoder = send(buffer, @"computeCommandEncoder");
            printf("   computeCommandEncoder -> %s\n", [describe(computeEncoder) UTF8String]);
        } @catch (NSException *why) {
            printf("   computeCommandEncoder RAISED %s: %s\n", [[why name] UTF8String], [[why reason] UTF8String]);
        }
        for (id pair in @[@[@"render", renderEncoder ?: (id)[NSNull null]],
                          @[@"compute", computeEncoder ?: (id)[NSNull null]]]) {
            NSString *which = pair[0];
            id encoder = pair[1];
            if (encoder == (id)[NSNull null]) continue;
            member(encoder, @"label", [NSString stringWithFormat:@"%@ encoder label", which]);
            member(encoder, @"commandBuffer", [NSString stringWithFormat:@"%@ encoder commandBuffer", which]);
            @try {
                void (*push)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
                push(encoder, NSSelectorFromString(@"pushDebugGroup:"), @"vMetalProbe");
                printf("   %s pushDebugGroup: answered\n", [which UTF8String]);
                void (*pop)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
                pop(encoder, NSSelectorFromString(@"popDebugGroup"));
                printf("   %s popDebugGroup: answered\n", [which UTF8String]);
            } @catch (NSException *why) {
                printf("   %s debug groups RAISED %s: %s\n", [which UTF8String], [[why name] UTF8String], [[why reason] UTF8String]);
            }
        }

        printf("\nendEncoding on each encoder that exists, then endCommandBuffer\n");
        @try {
            void (*end)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
            if (renderEncoder) { end(renderEncoder, NSSelectorFromString(@"endEncoding")); printf("   render endEncoding answered\n"); }
            if (computeEncoder) { end(computeEncoder, NSSelectorFromString(@"endEncoding")); printf("   compute endEncoding answered\n"); }
            end(buffer, NSSelectorFromString(@"endCommandBuffer"));
            printf("   endCommandBuffer answered\n");
        } @catch (NSException *why) {
            printf("   RAISED %s: %s\n", [[why name] UTF8String], [[why reason] UTF8String]);
        }
        member(buffer, @"status", @"status at the end");

        /* THE QUEUE'S COMMIT, IN A CHILD PROCESS, AND THE THIRD THING THIS PROBE GOT WRONG.
         *
         * -[MTL4CommandQueue commit:count:] takes a C ARRAY OF BUFFERS - MTL4CommandQueue.h:231 declares
         *
         *     - (void)commit:(const id<MTL4CommandBuffer> _Nonnull[_Nonnull])commandBuffers
         *              count:(NSUInteger)count;
         *
         * and "Enqueues an array of command buffers for execution" - so the two earlier versions of this
         * probe, which passed ONE buffer where an array was expected, made Apple's framework read the
         * object's own memory as the array's first element. The Segmentation fault they produced was
         * MINE, not Apple's, and the "this row is not answerable" conclusion that came with it was
         * retracted. An ended buffer is the NORMAL thing to commit: the header's own path is
         * -newCommandBuffer, -beginCommandBufferWithAllocator:, work, -endCommandBuffer, -commit:count:.
         *
         * IT IS A CHILD PROCESS because one of the two questions below ABORTS Apple's framework rather
         * than raising, and an abort in this process would lose every row above it. The child does the
         * commit and the parent records what became of it.
         */
        /* NOT MEASURED HERE, and the reason is fork-safety rather than a missing selector. Metal is not
         * fork-safe, so a commit cannot be measured in a child forked from a process that already holds a
         * device, a queue and a buffer - the signal such a child dies on says nothing about the commit. The
         * measurement is chain-commit.sh, which EXECs a fresh process per form, runs Apple's documented
         * sequence there, keeps the allocator alive until after the commit, waits for completion, and
         * records that process's own stderr and status as they are. Until it has run, this row says
         * "measured next" and nothing else. */
        printf("\nand the queue's commit: measured next, in a process of its own\n");
        printf("   NOT ASKED HERE - Metal is not fork-safe, so a child forked from this process would\n"
               "       answer a question about the fork. See chain-commit.sh.\n");

        /* The parent does not fork at all any more; the child helper is gone with it. */
    }
    return 0;
}