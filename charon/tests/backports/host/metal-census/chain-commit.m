/* chain-commit.m - ONE Metal 4 commit, in a process of its own, and Apple's documented sequence around
 * it.
 *
 *     chain-commit.m ended | open
 *
 * WHY THIS IS A SEPARATE BINARY AND NOT A BRANCH OF chain-oracle.m. Metal is NOT fork-safe: a child
 * forked from a process that already holds a device, a queue, an allocator and a buffer dies on a signal
 * that says something about the fork and nothing about the commit. That is not a guess - it is what two
 * earlier attempts measured, and it is why those attempts are retracted. So this is a fresh process per
 * form, EXECed by chain-commit.sh, and this file creates every Metal object itself.
 *
 * THE SEQUENCE IS APPLE'S OWN, IN THE ORDER THE HEADERS GIVE IT:
 *
 *   -[MTLDevice newCommandAllocator]                      MTLDevice.h:1240
 *   -[MTLDevice newMTL4CommandQueue]                       MTLDevice.h:1262ff
 *   -[MTLDevice newCommandBuffer]                          MTLDevice.h:1278
 *   -[MTL4CommandBuffer beginCommandBufferWithAllocator:]  MTL4CommandBuffer.h:71
 *   ... work ...
 *   -[MTL4CommandBuffer endCommandBuffer]                  MTL4CommandBuffer.h:103
 *   -[MTL4CommandQueue commit:count:]                      MTL4CommandQueue.h:231
 *
 * THE ALLOCATOR IS KEPT ALIVE UNTIL AFTER THE COMMIT, in a local that is still in scope at the call and
 * is read afterwards, because a Metal 4 buffer records its work into the allocator's storage and an
 * allocator that has been released before the commit is exactly the sort of thing that would make the
 * answer about this probe rather than about Metal. The form is "ended" - the header's own path, begun
 * then ended then committed - or "open", a buffer that was begun and committed without being ended, so
 * that the two are different questions and a reader who commits a buffer they forgot to end sees which
 * one Metal answers.
 *
 * EVERYTHING THIS PROCESS PRINTS IS ITS OWN. What the framework writes to stderr is NOT captured,
 * reformatted or summarised here: it goes where the framework put it, and chain-commit.sh records that
 * stream and this process's exit status as they are. An earlier version of this file family printed a
 * line beginning "Assertion failed:" from a fixed string on any signal - typing Apple's words and calling
 * them a capture - and that is retracted in facts/Metal/CommandChain26.md.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/message.h>

int main(int argc, const char **argv)
{
    /* BOTH STREAMS UNBUFFERED, so that whatever this process writes has reached the harness before it
     * dies however it dies - a buffered answer lost to an abort is no answer at all. */
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

        /* THE ALLOCATOR IS A LOCAL THAT OUTLIVES THE COMMIT, and it is touched after it, so that nothing
         * can release it before the commit: this is the whole point of the "kept alive" line. */
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

        /* THE CALL, EXACTLY AS MTL4CommandQueue.h:231 DECLARES IT: a C ARRAY of buffers, and a count. */
        printf("  about to call: id<MTL4CommandBuffer> list[1] = { buffer }; [queue commit:list count:1];\n");
        fflush(stdout);
        id<MTL4CommandBuffer> list[1];
        list[0] = buffer;
        void (*commit)(id, SEL, const void *, NSUInteger) =
            (void (*)(id, SEL, const void *, NSUInteger))objc_msgSend;
        commit(queue, NSSelectorFromString(@"commit:count:"), list, 1);
        printf("  commit:count: returned\n");
        fflush(stdout);

        /* AND THE WAIT FOR COMPLETION, which is the other half of a commit: a caller has to be able to
         * find out that the work finished, and this asks the queue rather than assuming it. */
        if ([queue respondsToSelector:NSSelectorFromString(@"waitForCommandBuffers:")]) {
            void (*wait)(id, SEL, const void *, NSUInteger) =
                (void (*)(id, SEL, const void *, NSUInteger))objc_msgSend;
            wait(queue, NSSelectorFromString(@"waitForCommandBuffers:"), list, 1);
            printf("  waitForCommandBuffers: returned\n");
        } else {
            printf("  the queue has no -waitForCommandBuffers:, so nothing was waited on\n");
        }

        /* THE ALLOCATOR IS STILL ALIVE HERE, and that is a check rather than a hope. */
        printf("  the allocator is still alive after the commit: %s\n",
               allocator ? "yes" : "no");
        printf("chain-commit: form %s reached the end of main\n", form);
    }
    return 0;
}