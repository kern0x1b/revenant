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

static NSString *text(id object) { return object ? [object description] : nil; }
static const char *utf8(NSString *string) { return string ? [string UTF8String] : "(nil)"; }

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
        printf("ZZZNoSuchNameRevenantR16 -> %s\n\n",
               NSClassFromString(@"ZZZNoSuchNameRevenantR16") ? "FOUND (wrong)" : "nil (right)");

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

        printf("\nand the queue's commit: measured next, in a process of its own\n");
        printf("   NOT ASKED HERE - Metal is not fork-safe, so a child forked from this process would\n"
               "       answer a question about the fork. See chain-commit.sh.\n");
    }
    return 0;
}
