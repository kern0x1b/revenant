#import "CharonMPS.h"

NSUInteger MPSImageBatchIncrementReadCount(MPSImageBatch *batch, NSInteger amount)
{
    NSHashTable *counted = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    NSUInteger distinct = 0;
    for (MPSImage *image in batch) {
        if (![image isKindOfClass:[MPSTemporaryImage class]] || [counted containsObject:image])
            continue;
        [counted addObject:image];
        distinct++;
        MPSTemporaryImage *temporary = (MPSTemporaryImage *)image;
        [temporary setReadCount:(NSUInteger)((NSInteger)[temporary readCount] + amount)];
    }
    return distinct;
}

void MPSImageBatchSynchronize(MPSImageBatch *batch, id<MTLCommandBuffer> cmdBuf)
{
    NSUInteger index = 0;
    for (MPSImage *image in batch) {
        if ([image isKindOfClass:[MPSTemporaryImage class]])
            [NSException raise:NSInternalInconsistencyException
                        format:@"MPSImageBatchSynchronize(): Error: image[%lu] is a temporary image and can not be read on the CPU.",
                               (unsigned long)index];
        index++;
    }
}
