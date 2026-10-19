#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

static NSMutableArray *order;

static void answer(const char *key, long value)
{
    printf("%s=%ld\n", key, value);
}

static long countOf(id<MTLLogContainer> logs)
{
    long count = 0;
    for (__unused id entry in logs)
        count++;
    return count;
}

static void lateHandler(const char *form, id<MTLCommandQueue> queue)
{
    id<MTLCommandBuffer> buffer = [queue commandBuffer];
    [buffer commit];
    [buffer waitUntilCompleted];
    answer("late.status.beforeHandler", buffer.status);
    __block long seen = -1;
    if (strcmp(form, "late-completed") == 0)
        [buffer addCompletedHandler:^(id<MTLCommandBuffer> cb) { seen = cb.status; }];
    else
        [buffer addScheduledHandler:^(id<MTLCommandBuffer> cb) { seen = cb.status; }];
    answer("late.handler.ran", seen != -1);
    answer("late.handler.status", seen);
}

int main(int argc, const char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        answer("device.present", device != nil);
        if (!device)
            return 2;

        id<MTLCommandQueue> queue = [device newCommandQueue];
        if (argc > 1) {
            lateHandler(argv[1], queue);
            return 0;
        }
        answer("queue.present", queue != nil);
        answer("queue.label.nil", queue.label == nil);
        answer("queue.device.same", queue.device == device);
        answer("queue.insertDebugCaptureBoundary.responds", [queue respondsToSelector:@selector(insertDebugCaptureBoundary)]);
        answer("queue.commandBufferWithDescriptor.responds", [queue respondsToSelector:@selector(commandBufferWithDescriptor:)]);

        id<MTLCommandBuffer> plain = [queue commandBuffer];
        answer("buffer.present", plain != nil);
        answer("buffer.status.fresh", plain.status);
        answer("buffer.label.nil", plain.label == nil);
        answer("buffer.device.same", plain.device == device);
        answer("buffer.commandQueue.same", plain.commandQueue == queue);
        answer("buffer.error.nil", plain.error == nil);
        answer("buffer.retainedReferences", plain.retainedReferences);
        answer("buffer.errorOptions.default", plain.errorOptions);
        answer("buffer.logs.count", countOf(plain.logs));
        answer("buffer.GPUStartTime.beforeCommit.zero", plain.GPUStartTime == 0);
        answer("buffer.GPUEndTime.beforeCommit.zero", plain.GPUEndTime == 0);
        answer("buffer.kernelStartTime.beforeCommit.zero", plain.kernelStartTime == 0);
        answer("buffer.kernelEndTime.beforeCommit.zero", plain.kernelEndTime == 0);
        answer("buffer.pushDebugGroup.responds", [plain respondsToSelector:@selector(pushDebugGroup:)]);
        answer("buffer.popDebugGroup.responds", [plain respondsToSelector:@selector(popDebugGroup)]);

        id<MTLCommandBuffer> unretained = [queue commandBufferWithUnretainedReferences];
        answer("unretained.retainedReferences", unretained.retainedReferences);

        MTLCommandBufferDescriptor *descriptor = [[MTLCommandBufferDescriptor alloc] init];
        answer("descriptor.retainedReferences.default", descriptor.retainedReferences);
        descriptor.retainedReferences = NO;
        descriptor.errorOptions = MTLCommandBufferErrorOptionEncoderExecutionStatus;
        id<MTLCommandBuffer> described = [queue commandBufferWithDescriptor:descriptor];
        answer("described.present", described != nil);
        answer("described.retainedReferences", described.retainedReferences);
        answer("described.errorOptions", described.errorOptions);

        order = [NSMutableArray array];
        id<MTLCommandBuffer> run = [queue commandBuffer];
        [run addCompletedHandler:^(id<MTLCommandBuffer> cb) {
            [order addObject:[NSString stringWithFormat:@"completed:%ld", (long)cb.status]];
        }];
        [run addScheduledHandler:^(id<MTLCommandBuffer> cb) {
            [order addObject:[NSString stringWithFormat:@"scheduled:%ld", (long)cb.status]];
        }];
        answer("run.status.beforeEnqueue", run.status);
        [run enqueue];
        answer("run.status.afterEnqueue", run.status);
        [run pushDebugGroup:@"outer"];
        [run pushDebugGroup:@"inner"];
        [run popDebugGroup];
        [run popDebugGroup];
        id<MTLComputeCommandEncoder> compute = [run computeCommandEncoderWithDispatchType:MTLDispatchTypeConcurrent];
        answer("run.computeWithDispatchType.present", compute != nil);
        [compute endEncoding];
        answer("run.status.beforeCommit", run.status);
        [run commit];
        answer("run.status.afterCommit", run.status);
        [run waitUntilCompleted];
        answer("run.status.afterWait", run.status);
        answer("run.error.nil.afterWait", run.error == nil);
        answer("run.GPUStartTime.positive", run.GPUStartTime > 0);
        answer("run.GPUEndTime.positive", run.GPUEndTime > 0);
        answer("run.GPUEndTime.notBeforeStart", run.GPUEndTime >= run.GPUStartTime);
        answer("run.kernelStartTime.positive", run.kernelStartTime > 0);
        answer("run.kernelEndTime.positive", run.kernelEndTime > 0);
        answer("run.kernelEndTime.notBeforeStart", run.kernelEndTime >= run.kernelStartTime);
        for (NSString *entry in order)
            printf("run.order.%s\n", [entry UTF8String]);

        [queue insertDebugCaptureBoundary];
        id<MTLCommandBuffer> after = [queue commandBuffer];
        [after commit];
        [after waitUntilCompleted];
        answer("after.boundary.status", after.status);

        id<MTLCommandBuffer> blitting = [queue commandBuffer];
        id<MTLBlitCommandEncoder> blit = [blitting blitCommandEncoder];
        answer("blitting.encoder.present", blit != nil);
        [blit endEncoding];
        [blitting commit];
        [blitting waitUntilCompleted];
        answer("blitting.status", blitting.status);
    }
    return 0;
}
