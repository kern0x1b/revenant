#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/message.h>
#include <dlfcn.h>

@interface revenantHost_MTL4CommandQueueDescriptor : NSObject <NSCopying>
@property (nonatomic, copy) id label;
@end
@interface revenantHost_MTL4CommandBufferOptions : NSObject <NSCopying>
@property (nonatomic, retain) id logState;
@end

static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) printf("  ok   %s\n", [what UTF8String]);
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

static void member(id object, NSString *key, NSString *name)
{
    if (!object) { printf("       %-34s -> (no object)\n", [name UTF8String]); return; }
    if (![object respondsToSelector:NSSelectorFromString(key)]) {
        printf("  ok   %-34s -> NOT A MEMBER of %s\n", [name UTF8String],
               [NSStringFromClass([(id)object class]) UTF8String]);
        return;
    }
    printf("  ok   %-34s -> %s\n", [name UTF8String], [[[object valueForKey:key] description] UTF8String]);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        checks++;
        if (NSClassFromString(@"ZZZNoSuchNameRevenantR16") == nil)
            printf("  ok   the control: ZZZNoSuchNameRevenantR16 is not a class of this framework\n");
        else {
            printf("  FAIL the control: ZZZNoSuchNameRevenantR16 exists, so this harness's answers mean nothing\n");
            failures++;
        }

        extern NSString *const MTL4CommandQueueErrorDomain __asm__("_MTL4CommandQueueErrorDomain");
        checks++;
        if (dlsym(RTLD_DEFAULT, "ZZZNoSuchNameRevenantR16") == NULL)
            printf("  ok   the control: ZZZNoSuchNameRevenantR16 is not a symbol of anything loaded\n");
        else {
            printf("  FAIL the control: ZZZNoSuchNameRevenantR16 was found\n");
            failures++;
        }
        check([MTL4CommandQueueErrorDomain isKindOfClass:[NSString class]],
              @"MTL4CommandQueueErrorDomain resolves to a string");
        printf("  ok   MTL4CommandQueueErrorDomain -> %s\n",
               [[MTL4CommandQueueErrorDomain description] UTF8String]);

        printf("the two descriptors, fresh, on both sides\n");
        {
            MTL4CommandQueueDescriptor *host = [[MTL4CommandQueueDescriptor alloc] init];
            revenantHost_MTL4CommandQueueDescriptor *port = [[revenantHost_MTL4CommandQueueDescriptor alloc] init];
            check(host.label == nil && port.label == nil, @"queue descriptor: label is nil on both sides");
            check([host respondsToSelector:@selector(feedbackQueue)] &&
                  [port respondsToSelector:@selector(feedbackQueue)],
                  @"queue descriptor: feedbackQueue is a member on both sides");
            id hostQueue = [host valueForKey:@"feedbackQueue"];
            id portQueue = [port valueForKey:@"feedbackQueue"];
            check(hostQueue == nil && portQueue == nil,
                  @"queue descriptor: feedbackQueue is nil on both sides");
            NSMutableString *mutable = [NSMutableString stringWithString:@"first"];
            host.label = mutable; port.label = mutable;
            [mutable appendString:@"-changed"];
            check(![host.label isEqualToString:@"first-changed"] && ![port.label isEqualToString:@"first-changed"],
                  @"queue descriptor: the label is a copy, so changing the caller's string changes neither");
            MTL4CommandQueueDescriptor *hostCopy = [host copy];
            revenantHost_MTL4CommandQueueDescriptor *portCopy = [port copy];
            id hostCopied = [hostCopy valueForKey:@"label"];
            id portCopied = [portCopy valueForKey:@"label"];
            check([hostCopied isEqual:[host valueForKey:@"label"]] &&
                  [portCopied isEqual:[port valueForKey:@"label"]],
                  @"queue descriptor: a copy carries the label each side holds");
        }
        {
            MTL4CommandBufferOptions *host = [[MTL4CommandBufferOptions alloc] init];
            revenantHost_MTL4CommandBufferOptions *port = [[revenantHost_MTL4CommandBufferOptions alloc] init];
            check([host valueForKey:@"logState"] == nil && [port valueForKey:@"logState"] == nil,
                  @"buffer options: logState is nil on both sides");
            check([[host copy] valueForKey:@"logState"] == nil,
                  @"buffer options: APPLE's copy carries the member, which is nil here");
            check([[port copy] valueForKey:@"logState"] == nil,
                  @"buffer options: the PORT's copy carries it too, which is nil here");
        }

        printf("AND THE LIVE CHAIN, which the first version of this case said did not exist\n");
        {
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();
            id allocator = [device performSelector:NSSelectorFromString(@"newCommandAllocator")];
            id buffer = [device performSelector:NSSelectorFromString(@"newCommandBuffer")];
            check(allocator != nil, @"APPLE's device vends a Metal 4 command allocator (MTLDevice.h:1240)");
            check(buffer != nil, @"APPLE's device vends a Metal 4 command buffer (MTLDevice.h:1278)");
            if (!buffer) {
                printf("       no buffer to ask about members on; the member rows below are NOT measured\n");
            }

            check(buffer && ![buffer respondsToSelector:NSSelectorFromString(@"status")],
                  @"APPLE's Metal 4 command buffer has NO -status member");
            check(buffer && ![buffer respondsToSelector:NSSelectorFromString(@"commandQueue")],
                  @"and NO -commandQueue member either");

            @try {
                void (*begin)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
                if (buffer) begin(buffer, NSSelectorFromString(@"beginCommandBufferWithAllocator:"), allocator);
                printf("  ok   APPLE's -beginCommandBufferWithAllocator: answers without raising\n");
            } @catch (NSException *why) {
                printf("  FAIL APPLE's -beginCommandBufferWithAllocator: raised %s: %s\n",
                       [[why name] UTF8String], [[why reason] UTF8String]);
                failures++;
            }

            id encoder = buffer ? [buffer performSelector:NSSelectorFromString(@"computeCommandEncoder")] : nil;
            check(encoder != nil, @"APPLE's compute encoder is vended, and it is a live object");
            if (encoder) {
                member(encoder, @"label", @"compute encoder label");
                check([[encoder valueForKey:@"commandBuffer"] isEqual:buffer],
                      @"and its -commandBuffer answers the very buffer it came from");
            }
            Class passDescriptor = NSClassFromString(@"MTL4RenderPassDescriptor");
            id renderEncoder = nil;
            if (buffer && passDescriptor) {
                id (*withDescriptor)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;
                renderEncoder = withDescriptor(buffer, NSSelectorFromString(@"renderCommandEncoderWithDescriptor:"),
                                              [[passDescriptor alloc] init]);
            }
            printf("  ok   APPLE's render encoder for a pass with no attachments: %s\n",
                   renderEncoder ? "an object" : "nil, and no exception");
        }

        printf("%d checks\n", checks);
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
