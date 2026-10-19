#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/message.h>

int main(int argc, const char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    const char *form = argc > 1 ? argv[1] : "ended";
    BOOL ended = strcmp(form, "ended") == 0;
    printf("chain-commit: form %s, process %d\n", form, (int)getpid());
    fflush(stdout);

    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) { printf("  no Metal device\n"); return 2; }
        printf("  the device: %s\n", [[device name] UTF8String]);

        id (*plain)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        SEL queueSelector = NSSelectorFromString(@"newMTL4CommandQueue");
        SEL allocatorSelector = NSSelectorFromString(@"newCommandAllocator");
        SEL bufferSelector = NSSelectorFromString(@"newCommandBuffer");
        if (![device respondsToSelector:queueSelector] ||
            ![device respondsToSelector:allocatorSelector] ||
            ![device respondsToSelector:bufferSelector]) {
            printf("  this device does not vend the Metal 4 queue, allocator and buffer\n");
            return 2;
        }

        id allocator = plain(device, allocatorSelector);
        id queue = plain(device, queueSelector);
        id buffer = plain(device, bufferSelector);
        printf("  allocator %s, queue %s, buffer %s\n",
               [NSStringFromClass([(id)allocator class]) UTF8String],
               [NSStringFromClass([(id)queue class]) UTF8String],
               [NSStringFromClass([(id)buffer class]) UTF8String]);
        if (!allocator || !queue || !buffer) { printf("  something was nil; not committing\n"); return 2; }

        void (*begin)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
        begin(buffer, NSSelectorFromString(@"beginCommandBufferWithAllocator:"), allocator);
        printf("  beginCommandBufferWithAllocator: answered\n");

        if (ended) {
            void (*endBuffer)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
            endBuffer(buffer, NSSelectorFromString(@"endCommandBuffer"));
            printf("  endCommandBuffer answered\n");
        } else {
            printf("  endCommandBuffer DELIBERATELY NOT CALLED - this is the \"open\" form\n");
        }

        printf("  about to call: id<MTL4CommandBuffer> list[1] = { buffer }; [queue commit:list count:1];\n");
        fflush(stdout);
        id<MTL4CommandBuffer> list[1];
        list[0] = buffer;
        void (*commit)(id, SEL, const void *, NSUInteger) =
            (void (*)(id, SEL, const void *, NSUInteger))objc_msgSend;
        commit(queue, NSSelectorFromString(@"commit:count:"), list, 1);
        printf("  commit:count: returned\n");
        fflush(stdout);

        if ([queue respondsToSelector:NSSelectorFromString(@"waitForCommandBuffers:")]) {
            void (*wait)(id, SEL, const void *, NSUInteger) =
                (void (*)(id, SEL, const void *, NSUInteger))objc_msgSend;
            wait(queue, NSSelectorFromString(@"waitForCommandBuffers:"), list, 1);
            printf("  waitForCommandBuffers: returned\n");
        } else {
            printf("  the queue has no -waitForCommandBuffers:, so nothing was waited on\n");
        }

        printf("  the allocator is still alive after the commit: %s\n",
               allocator ? "yes" : "no");
        printf("chain-commit: form %s reached the end of main\n", form);
    }
    return 0;
}
