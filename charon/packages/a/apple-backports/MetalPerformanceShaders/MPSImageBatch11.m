// MPSImageBatchIncrementReadCount() and MPSImageBatchSynchronize(), from MPSImage.h of the iPhoneOS 16.4 SDK
// (the batch helpers at MPSImage.h:112-141), introduced at 11.3.
//
// Both are measured on the macOS 26 host (tests/backports/host/mps-image-batch/run.sh), and the measurements decide
// what they do here:
//
// * IncrementReadCount adds the amount to the read count of each DISTINCT image in the batch, once per image however
//   often it is listed, and returns how many distinct images it counted. Only a temporary image has a read count
//   (MPSTemporaryImage.h declares it, and a plain MPSImage does not), so a plain image in the batch is not counted:
//   a batch of plain images counts 0, and a mixed batch counts its temporary images only.
// * Synchronize calls synchronizeResource: on each resource of the batch. A plain image's resource is CPU-resident
//   here already (facts/MetalPerformanceShaders/MPSImageBatch.md), so there is nothing to synchronise and the call
//   does nothing, as Apple's does on a plain image. A temporary image cannot be read on the CPU, and Apple refuses
//   the batch with an assertion naming the index of the first such image. The port refuses it the same way.

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
