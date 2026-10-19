#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor : NSObject
@property (nonatomic, retain) id sampleBuffer;
@property (nonatomic) NSUInteger startOfEncoderSampleIndex;
@property (nonatomic) NSUInteger endOfEncoderSampleIndex;
@end

@interface charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray : NSObject
- (charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)attachment
    atIndexedSubscript:(NSUInteger)index;
@end

@interface charonHost_MTLAccelerationStructurePassDescriptor : NSObject
@property (nonatomic, retain) id sampleBufferAttachments;
@end

@interface charonHost_MTLIOCommandQueueDescriptor : NSObject
@property (nonatomic) NSUInteger maxCommandBufferCount;
@property (nonatomic) MTLIOPriority priority;
@property (nonatomic) MTLIOCommandQueueType type;
@property (nonatomic) NSUInteger maxCommandsInFlight;
@property (nonatomic, retain) id scratchBufferAllocator;
@end

static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

static void same_u(NSUInteger port, NSUInteger host, NSString *what)
{
    check(port == host, ([NSString stringWithFormat:@"%@: the port %lu and Apple's own object %lu",
                          what, (unsigned long)port, (unsigned long)host]));
}

static void same_i(long port, long host, NSString *what)
{
    check(port == host, ([NSString stringWithFormat:@"%@: the port %ld and Apple's own object %ld",
                          what, port, host]));
}

static id hostSlot(id array, NSUInteger index)
{
    @try {
        return [(MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *)array
            objectAtIndexedSubscript:index];
    } @catch (NSException *why) {
        printf("       Apple's side raised at %lu: %s\n", (unsigned long)index, [[why reason] UTF8String]);
        return nil;
    }
}

static id portSlot(id array, NSUInteger index)
{
    @try {
        return [(charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *)array
            objectAtIndexedSubscript:index];
    } @catch (NSException *why) {
        printf("       the port raised at %lu: %s\n", (unsigned long)index, [[why reason] UTF8String]);
        return nil;
    }
}

int main(void)
{
    @autoreleasepool {
        printf("MTLAccelerationStructurePassSampleBufferAttachmentDescriptor\n");
        {
            MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *host =
                [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
            charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *port =
                [[charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
            check(host.sampleBuffer == nil && port.sampleBuffer == nil,
                  @"fresh: sampleBuffer is nil on both sides - the device-backed section below is what measures it");
            same_u(port.startOfEncoderSampleIndex, host.startOfEncoderSampleIndex,
                   @"fresh: startOfEncoderSampleIndex");
            same_u(port.endOfEncoderSampleIndex, host.endOfEncoderSampleIndex,
                   @"fresh: endOfEncoderSampleIndex");
            check(port.startOfEncoderSampleIndex == MTLCounterDontSample
                      && host.startOfEncoderSampleIndex == MTLCounterDontSample,
                  @"fresh: startOfEncoderSampleIndex is MTLCounterDontSample, the header's 'no sample'");
            [port setStartOfEncoderSampleIndex:3];
            [host setStartOfEncoderSampleIndex:3];
            [port setEndOfEncoderSampleIndex:4];
            [host setEndOfEncoderSampleIndex:4];
            same_u(port.startOfEncoderSampleIndex, host.startOfEncoderSampleIndex,
                   @"after a set: startOfEncoderSampleIndex = 3");
            same_u(port.endOfEncoderSampleIndex, host.endOfEncoderSampleIndex,
                   @"after a set: endOfEncoderSampleIndex = 4");
            MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *hostCopy = [host copy];
            charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *portCopy = [port copy];
            same_u(portCopy.startOfEncoderSampleIndex, hostCopy.startOfEncoderSampleIndex,
                   @"copy: startOfEncoderSampleIndex");
            same_u(portCopy.endOfEncoderSampleIndex, hostCopy.endOfEncoderSampleIndex,
                   @"copy: endOfEncoderSampleIndex");
        }

        printf("MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray\n");
        {
            MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *host =
                [MTLAccelerationStructurePassDescriptor accelerationStructurePassDescriptor]
                    .sampleBufferAttachments;
            charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *port =
                [[charonHost_MTLAccelerationStructurePassDescriptor alloc] init].sampleBufferAttachments;
            check(host != nil && port != nil,
                  @"a fresh pass descriptor's array is there on both sides, and the port's needs no device");
            id hostSlots[4], portSlots[4];
            for (NSUInteger index = 0; index < 4; index++) {
                hostSlots[index] = hostSlot(host, index);
                portSlots[index] = portSlot(port, index);
            }
            check(hostSlots[0] && hostSlots[1] && hostSlots[2] && hostSlots[3],
                  @"four reads of indices 0 to 3 each answer an attachment on Apple's side");
            check(portSlots[0] && portSlots[1] && portSlots[2] && portSlots[3],
                  @"four reads of indices 0 to 3 each answer an attachment on the port's side");
            check(hostSlots[0] != hostSlots[1] && hostSlots[0] != hostSlots[2]
                      && hostSlots[0] != hostSlots[3],
                  @"the four slots are four distinct attachments on Apple's side");
            check(portSlots[0] != portSlots[1] && portSlots[0] != portSlots[2]
                      && portSlots[0] != portSlots[3],
                  @"the four slots are four distinct attachments on the port's side");
            check(hostSlot(host, 0) == hostSlots[0] && portSlot(port, 0) == portSlots[0],
                  @"two reads of one index are the same attachment on both sides: an unwritten slot is kept");

            MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *hostWritten =
                [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
            [hostWritten setStartOfEncoderSampleIndex:11];
            [hostWritten setEndOfEncoderSampleIndex:12];
            [host setObject:hostWritten atIndexedSubscript:1];
            charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *portWritten =
                [[charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
            [portWritten setStartOfEncoderSampleIndex:11];
            [portWritten setEndOfEncoderSampleIndex:12];
            [port setObject:portWritten atIndexedSubscript:1];
            id hostBack = hostSlot(host, 1);
            id portBack = portSlot(port, 1);
            same_u([hostBack startOfEncoderSampleIndex], [portBack startOfEncoderSampleIndex],
                   @"after a write at 1: startOfEncoderSampleIndex");
            same_u([hostBack endOfEncoderSampleIndex], [portBack endOfEncoderSampleIndex],
                   @"after a write at 1: endOfEncoderSampleIndex");
            check(hostBack != hostWritten && portBack != portWritten,
                  @"a write copies: the attachment read back is not the one handed in, on either side");
            same_u([hostSlots[0] startOfEncoderSampleIndex], [portSlots[0] startOfEncoderSampleIndex],
                   @"slot 0 after the write at 1: unchanged on both sides");
            [host setObject:nil atIndexedSubscript:1];
            [port setObject:nil atIndexedSubscript:1];
            id hostReset = hostSlot(host, 1);
            id portReset = portSlot(port, 1);
            same_u([hostReset startOfEncoderSampleIndex], [portReset startOfEncoderSampleIndex],
                   @"after a nil write at 1: startOfEncoderSampleIndex is back to the default");
            same_u([hostReset endOfEncoderSampleIndex], [portReset endOfEncoderSampleIndex],
                   @"after a nil write at 1: endOfEncoderSampleIndex is back to the default");
            check(hostReset != hostBack && portReset != portBack,
                  @"a nil write resets the slot to a NEW default attachment, on either side");

            id portAtFour = nil;
            BOOL portAnswered = YES;
            @try {
                portAtFour = [port objectAtIndexedSubscript:4];
            } @catch (NSException *why) {
                portAnswered = NO;
                printf("       raised %s: %s\n", [[why name] UTF8String], [[why reason] UTF8String]);
            }
            check(!portAnswered && portAtFour == nil,
                  @"index 4 is refused by the port: no attachment is handed back");
        }

        printf("MTLAccelerationStructurePassDescriptor\n");
        {
            MTLAccelerationStructurePassDescriptor *host =
                [MTLAccelerationStructurePassDescriptor accelerationStructurePassDescriptor];
            charonHost_MTLAccelerationStructurePassDescriptor *port =
                [[charonHost_MTLAccelerationStructurePassDescriptor alloc] init];
            check([host isKindOfClass:[MTLAccelerationStructurePassDescriptor class]]
                      && [port isKindOfClass:[charonHost_MTLAccelerationStructurePassDescriptor class]],
                  @"both sides are a kind of the class the case names; Apple's is a private subclass of it");
            check(host.sampleBufferAttachments != nil && port.sampleBufferAttachments != nil,
                  @"sampleBufferAttachments is there on a fresh descriptor on both sides");
            MTLAccelerationStructurePassDescriptor *hostCopy = nil;
            charonHost_MTLAccelerationStructurePassDescriptor *portCopy = nil;
            @try { hostCopy = [host copy]; } @catch (NSException *why) {
                printf("       Apple's side raised on -copy: %s\n", [[why reason] UTF8String]);
            }
            @try { portCopy = [port copy]; } @catch (NSException *why) {
                printf("       the port raised on -copy: %s\n", [[why reason] UTF8String]);
            }
            check(hostCopy != nil && portCopy != nil, @"a copy of the pass descriptor is made on both sides");
            check(hostCopy.sampleBufferAttachments != host.sampleBufferAttachments
                      && portCopy.sampleBufferAttachments != port.sampleBufferAttachments,
                  @"a copy's array is a different object from the original's, on either side");
            MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *hostCopySlot =
                hostSlot(hostCopy.sampleBufferAttachments, 2);
            charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *portCopySlot =
                portSlot(portCopy.sampleBufferAttachments, 2);
            [hostCopySlot setStartOfEncoderSampleIndex:21];
            [portCopySlot setStartOfEncoderSampleIndex:21];
            same_u([hostSlot(host.sampleBufferAttachments, 2) startOfEncoderSampleIndex],
                   [portSlot(port.sampleBufferAttachments, 2) startOfEncoderSampleIndex],
                   @"slot 2 of the ORIGINAL after a write through the copy's array: unchanged on both sides");
        }

        printf("MTLIOCommandQueueDescriptor\n");
        {
            MTLIOCommandQueueDescriptor *host = [[MTLIOCommandQueueDescriptor alloc] init];
            charonHost_MTLIOCommandQueueDescriptor *port = [[charonHost_MTLIOCommandQueueDescriptor alloc] init];
            same_u(port.maxCommandBufferCount, host.maxCommandBufferCount,
                   @"fresh: maxCommandBufferCount - Apple's own default, which the header does not state");
            check(host.maxCommandBufferCount == 64,
                  @"fresh: Apple's own maxCommandBufferCount is 64, the number the port carries");
            same_i((long)port.priority, (long)host.priority, @"fresh: priority");
            check(host.priority == MTLIOPriorityNormal && MTLIOPriorityHigh == 0,
                  @"fresh: priority is MTLIOPriorityNormal, NOT the enumeration's own zero");
            same_i((long)port.type, (long)host.type, @"fresh: type");
            same_u(port.maxCommandsInFlight, host.maxCommandsInFlight, @"fresh: maxCommandsInFlight");
            check(host.scratchBufferAllocator == nil && port.scratchBufferAllocator == nil,
                  @"fresh: scratchBufferAllocator is nil on both sides, and it is not measured");
            [port setMaxCommandBufferCount:7];
            [host setMaxCommandBufferCount:7];
            [port setPriority:MTLIOPriorityLow];
            [host setPriority:MTLIOPriorityLow];
            [port setType:MTLIOCommandQueueTypeSerial];
            [host setType:MTLIOCommandQueueTypeSerial];
            [port setMaxCommandsInFlight:9];
            [host setMaxCommandsInFlight:9];
            same_u(port.maxCommandBufferCount, host.maxCommandBufferCount, @"after a set: maxCommandBufferCount = 7");
            same_i((long)port.priority, (long)host.priority, @"after a set: priority = Low");
            same_i((long)port.type, (long)host.type, @"after a set: type = Serial");
            same_u(port.maxCommandsInFlight, host.maxCommandsInFlight, @"after a set: maxCommandsInFlight = 9");
            MTLIOCommandQueueDescriptor *hostCopy = [host copy];
            charonHost_MTLIOCommandQueueDescriptor *portCopy = [port copy];
            same_u(portCopy.maxCommandBufferCount, hostCopy.maxCommandBufferCount, @"copy: maxCommandBufferCount");
            same_i((long)portCopy.priority, (long)hostCopy.priority, @"copy: priority");
            same_i((long)portCopy.type, (long)hostCopy.type, @"copy: type");
            same_u(portCopy.maxCommandsInFlight, hostCopy.maxCommandsInFlight, @"copy: maxCommandsInFlight");
            check(hostCopy.maxCommandsInFlight == 0 && host.maxCommandsInFlight == 9,
                  @"Apple's own -copyWithZone: does not carry maxCommandsInFlight, and the port matches that");
        }

        printf("the sample buffer, with a real MTLCounterSampleBuffer on both sides\n");
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        check(device != nil, @"there is a Metal device, which is what this section needs and the one above did not");
        if (device) {
            id<MTLCounterSet> timestampSet = nil;
            for (id<MTLCounterSet> set in device.counterSets)
                if ([set.name isEqualToString:MTLCommonCounterSetTimestamp]) { timestampSet = set; break; }
            check(timestampSet != nil, @"Apple's own device has the timestamp counter set the header names");
            MTLCounterSampleBufferDescriptor *counterDescriptor = [[MTLCounterSampleBufferDescriptor alloc] init];
            counterDescriptor.counterSet = timestampSet;
            counterDescriptor.sampleCount = 1;
            NSError *counterError = nil;
            id<MTLCounterSampleBuffer> buffer = [device newCounterSampleBufferWithDescriptor:counterDescriptor error:&counterError];
            check(buffer != nil, ([NSString stringWithFormat:@"Apple's own device makes a counter sample buffer, which is what the port is handed%@",
                                   buffer ? @"" : [@": " stringByAppendingString:[counterError localizedDescription]]]));
            if (buffer) {
                MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *hostAttachment =
                    [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
                charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *portAttachment =
                    [[charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
                check(hostAttachment.sampleBuffer == nil && portAttachment.sampleBuffer == nil,
                      @"fresh: sampleBuffer is nil on both sides");
                [hostAttachment setSampleBuffer:buffer];
                [portAttachment setSampleBuffer:buffer];
                check(hostAttachment.sampleBuffer == buffer,
                      @"after a set: APPLE's own attachment returns the very object it was given");
                check(portAttachment.sampleBuffer == buffer,
                      @"after a set: the PORT's attachment returns the very object it was given - identity within its own side");

                MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *hostAttachmentCopy = [hostAttachment copy];
                charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *portAttachmentCopy = [portAttachment copy];
                check(hostAttachmentCopy.sampleBuffer == buffer,
                      @"a copy: APPLE's own copy carries the sample buffer");
                check(portAttachmentCopy.sampleBuffer == buffer,
                      @"a copy: the PORT's copy carries the sample buffer");

                MTLAccelerationStructurePassDescriptor *hostPass = [[MTLAccelerationStructurePassDescriptor alloc] init];
                charonHost_MTLAccelerationStructurePassDescriptor *portPass = [[charonHost_MTLAccelerationStructurePassDescriptor alloc] init];
                [hostPass.sampleBufferAttachments setObject:hostAttachment atIndexedSubscript:0];
                [portPass.sampleBufferAttachments setObject:portAttachment atIndexedSubscript:0];
                check(hostSlot(hostPass.sampleBufferAttachments, 0) != nil,
                      @"through the array: APPLE's own pass descriptor holds the attachment at index 0");
                check(portSlot(portPass.sampleBufferAttachments, 0) != nil,
                      @"through the array: the PORT's pass descriptor holds the attachment at index 0");
                check(((MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)
                          hostSlot(hostPass.sampleBufferAttachments, 0)).sampleBuffer == buffer,
                      @"through the array: APPLE's own attachment still holds the real sample buffer");
                check(((charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)
                          portSlot(portPass.sampleBufferAttachments, 0)).sampleBuffer == buffer,
                      @"through the array: the PORT's attachment still holds the real sample buffer");

                [hostPass.sampleBufferAttachments setObject:nil atIndexedSubscript:0];
                [portPass.sampleBufferAttachments setObject:nil atIndexedSubscript:0];
                same_u(((charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)
                         portSlot(portPass.sampleBufferAttachments, 0)).startOfEncoderSampleIndex,
                       ((MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)
                         hostSlot(hostPass.sampleBufferAttachments, 0)).startOfEncoderSampleIndex,
                       @"after a nil at index 0: startOfEncoderSampleIndex is back to the default on both sides");
                check(((MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)
                          hostSlot(hostPass.sampleBufferAttachments, 0)).sampleBuffer == nil &&
                      ((charonHost_MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)
                          portSlot(portPass.sampleBufferAttachments, 0)).sampleBuffer == nil,
                      @"after a nil at index 0: both sides' attachment has no sample buffer again");
            }
        }

        printf("%d checks, each one against Apple's own object; the descriptor ones need no device and the sample buffer one does\n", checks);
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
