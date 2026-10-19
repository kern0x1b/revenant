#import "CharonMetal.h"
#import "CharonMetalProtocols.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// THE DESCRIPTORS THAT ARRIVED IN iOS 16, and they are the same kind of thing as the twenty in
// MTLDescriptors14.m: plain data holders that say what a pass or a queue is built FROM and ask the
// device nothing. That is the whole case for carrying them, and it is why the three acceleration
// structure pass descriptors - which are MTLComputePassDescriptor's own family member for member,
// without the dispatch type - were not left absent while their compute, render and resource-state
// siblings are carried.
//
// NOTHING HERE CREATES A DEVICE, and the host differential is built on that. Each side is
// `[[X alloc] init]`, the port's class and Apple's, and a descriptor asks a device nothing - which
// facts/Metal/DeviceOnThisMachine.md measures - so no case in this file creates one.
//
// THE SAMPLE BUFFER EACH ATTACHMENT CARRIES IS A DEVICE-MADE OBJECT and this port makes none - not
// this release's and not the port's - but the DESCRIPTOR's handling of one is measured, because a
// device to make one with is no longer a wall: tests/backports/host/metal-census/descriptors16.sh
// makes a real MTLCounterSampleBuffer on Apple's own device (the timestamp counter set,
// MTLCounters.h:65), hands that one object to both sides, and compares what each returns, what each
// copy carries, and what each side's array holds after the attachment goes through it and a nil takes
// it away again. 57 checks (43 before this section), and the reset mutant M7 is the one only that section can
// catch. What is
// still NOT measured is what a sample buffer's CONTENTS are, which needs a command encoder this port
// vends no ray tracing path for; facts/Metal/Descriptors16.md says so.
//
// WHAT IS NOT HERE, and it is the half a caller has to know: this port vends no acceleration
// structure command encoder and no IO command queue, so nothing in it ever reads a descriptor made
// here. `-[MTLCommandBuffer accelerationStructureCommandEncoderWithDescriptor:]` and
// `-[MTLDevice newIOQueueWithDescriptor:error:]` are Metal facilities this release's GPU has not, and
// a caller that builds one of these descriptors gets an object it can read and no object to hand it
// to. The five MTLIO* protocols and the mesh pipeline descriptor are the rows that stay absent for
// that reason, and their reasons say which facility is missing rather than that the class arrived
// late.
//
// EVERY VALUE BELOW IS APPLE'S OWN, MEASURED, not read off a header: the counter's "no sample" index,
// the four slots of the attachment array, the queue's 64 command buffers, and the three of the queue
// descriptor's five members a copy carries. The commands and their output are in
// facts/Metal/Descriptors16.md; a reviewer who cannot re-run them cannot settle a row here either.

#pragma mark - the acceleration structure pass

// ONE ATTACHMENT OF THE PASS: the sample buffer the encoder's counters are written into, and the two
// indices saying where in it the sample taken at the start and the sample taken at the end of
// processing go.
//
// THE TWO INDICES START AT MTLCounterDontSample, which is the header's own name for "no sample here"
// and is NSUIntegerMax - NOT zero, and not a value this file chose. Measured against Apple's own fresh
// object: start and end both read 18446744073709551615, and a value the header does not give a
// default for would have been a zero that reads as "sample index 0".
@implementation MTLAccelerationStructurePassSampleBufferAttachmentDescriptor {
    id<MTLCounterSampleBuffer> _sampleBuffer;
    NSUInteger _startOfEncoderSampleIndex;
    NSUInteger _endOfEncoderSampleIndex;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _startOfEncoderSampleIndex = MTLCounterDontSample;
        _endOfEncoderSampleIndex = MTLCounterDontSample;
    }
    return self;
}

@synthesize sampleBuffer = _sampleBuffer;
@synthesize startOfEncoderSampleIndex = _startOfEncoderSampleIndex;
@synthesize endOfEncoderSampleIndex = _endOfEncoderSampleIndex;

// The header derives this class from <NSCopying>, and a descriptor a caller copies and then changes
// must not change the original: the copy carries all three values, measured - a copy of an attachment
// whose indices were set to 3 and 4 reads 3 and 4 back.
- (id)copyWithZone:(NSZone *)zone
{
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *copy =
        [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
    copy.sampleBuffer = _sampleBuffer;
    copy.startOfEncoderSampleIndex = _startOfEncoderSampleIndex;
    copy.endOfEncoderSampleIndex = _endOfEncoderSampleIndex;
    return copy;
}

@end

// THE FOUR SLOTS. The header declares exactly two members and no superclass, and this answers
// exactly that: the two indexed members, and NOT -count, -objectAtIndex: or -setObject:atIndex:,
// which Apple's own object also does not answer (measured: all three are 0 there).
//
// FOUR IS APPLE'S NUMBER, not the header's - the header says nothing about how many slots there are -
// and it is measured, one index per process because an index past the end stops the process: Apple's
// own object answers indices 0 to 3 with an attachment descriptor and traps on 4 and above, with
// `attachmentIndex(4) must be < 4`. The same bound and the same message are Apple's for the compute,
// render and resource-state arrays, so this is one bound and not four.
//
// A READ OF AN UNWRITTEN SLOT MAKES A DESCRIPTOR and keeps it, so two reads of one index are the same
// object and a caller can set one through the array without a write first - measured, and that is
// what lets a caller fill slot 2 without having filled slot 1.
//
// A WRITE COPIES, because the header says it always uses copy semantics, and that is measured
// too: the attachment handed in and the one read back are different objects with the same values. A
// nil write RESETS the slot to a fresh descriptor, which is what the header means by setting the attachment state at a valid
// index set to nil, which returns it to default values - measured: the slot reads a new object whose indices are MTLCounterDontSample again.
//
// THIS ARRAY IS NOT SHARED WITH THE THREE IN MTLDescriptors14.m, and it is worth saying why rather than
// leaving a reviewer to find a near-copy. They are three classes of three other releases' objects, each
// in the file that carries its own release's API, and a C helper shared between two of those files is the
// undefined-symbol trap this repository's own contract names: a file whose exports a band's release
// already has is left out of that band, so the call is `Undefined symbols` in later bands only - a gate
// that links one band passes and only the all-band build of the canon shows it. The classes are also not
// interchangeable: each holds its own attachment type, so a shared body would still need three thin
// forwarders, which is more code than the twenty lines it replaces. AND THEY DO NOT AGREE: the three 14.0
// arrays grow to whatever index is written, where Apple's own bound is four for every one of them -
// measured on the host, one index per process, and it is in facts/Metal/Descriptors16.md. This one is
// bounded because that is what Apple's own object does; the other three are another band's rows and
// this file does not touch them.
@interface MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray () {
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *_slots[4];
}
@end

// Apple's own out-of-range answer is a C assertion, which stops the process. This raises a catchable
// NSException carrying the same condition and the same words, because on this release an uncaught
// exception prints the condition and aborts just as an assertion does, and a caller that meant to
// read four slots has a bug an exception names where a trap would not. It is a difference from Metal
// and facts/Metal/Descriptors16.md says so in one line.
static void CharonMetalRefuseAttachmentIndex(NSString *selector, NSUInteger index)
{
    [NSException raise:NSInvalidArgumentException
                format:@"%@: attachmentIndex(%lu) must be < 4", selector, (unsigned long)index];
}

@implementation MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray

- (MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)index
{
    if (index >= 4) {
        CharonMetalRefuseAttachmentIndex(@"objectAtIndexedSubscript:", index);
        return nil;
    }
    if (!_slots[index]) {
        _slots[index] = [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptor alloc] init];
    }
    return _slots[index];
}

- (void)setObject:(MTLAccelerationStructurePassSampleBufferAttachmentDescriptor *)attachment
    atIndexedSubscript:(NSUInteger)index
{
    if (index >= 4) {
        CharonMetalRefuseAttachmentIndex(@"setObject:atIndexedSubscript:", index);
        return;
    }
    _slots[index] = attachment ? [attachment copy] : nil;
}

@end

// THE PASS DESCRIPTOR ITSELF: the header describes it as a collection of attachments for building a concrete
// acceleration structure encoder. It declares one member of its own - the array - and the array is
// READONLY, so a fresh descriptor makes one, the way Apple's own does: measured, a fresh
// `+accelerationStructurePassDescriptor` and a plain `-init` both hand back a non-nil array whose four
// slots are four distinct descriptors.
//
// `+accelerationStructurePassDescriptor` is NOT implemented here and no row carries it. Apple's own
// factory answers a private subclass of the public class (measured:
// MTLAccelerationStructurePassDescriptorInternal), and a private type this port does not have is not
// something to invent; `[[MTLAccelerationStructurePassDescriptor alloc] init]`, which Apple's own
// object answers as well, is the way to make one and is what the differential uses on both sides.
@interface MTLAccelerationStructurePassDescriptor () {
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *_sampleBufferAttachments;
}
@end

@implementation MTLAccelerationStructurePassDescriptor

@synthesize sampleBufferAttachments = _sampleBufferAttachments;

- (instancetype)init
{
    if ((self = [super init]))
        _sampleBufferAttachments = [[MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray alloc] init];
    return self;
}

// A copy gets ITS OWN array, not the original's: measured, a copied descriptor's
// sampleBufferAttachments is a different object, so writing through the copy's array does not change
// the descriptor it was copied from.
- (id)copyWithZone:(NSZone *)zone
{
    MTLAccelerationStructurePassDescriptor *copy = [[MTLAccelerationStructurePassDescriptor alloc] init];
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *from = _sampleBufferAttachments;
    MTLAccelerationStructurePassSampleBufferAttachmentDescriptorArray *into = copy.sampleBufferAttachments;
    for (NSUInteger index = 0; index < 4; index++) {
        [into setObject:[from objectAtIndexedSubscript:index] atIndexedSubscript:index];
    }
    return copy;
}

@end

#pragma mark - the IO command queue

// THE DESCRIPTOR AN IO QUEUE IS MADE FROM: how many command buffers may be in flight, at what
// priority, serial or concurrent, how many IO commands at once, and the allocator the queue asks for
// scratch memory. It is data, and it is carried for the same reason as every descriptor here: a
// caller can build it, fill it and read it back.
//
// THE FOUR NUMBERS ARE APPLE'S OWN, MEASURED, and three of the four are not the value a C
// enumeration would suggest: a fresh descriptor answers maxCommandBufferCount 64 - the header says
// only that it is the maximum, and says nothing about the default - priority MTLIOPriorityNormal (1,
// while the enumeration's own zero is MTLIOPriorityHigh), type MTLIOCommandQueueTypeConcurrent (0,
// which IS the enumeration's zero) and maxCommandsInFlight 0, which the header documents as meaning the system chooses the maximum,
//
// A COPY CARRIES THREE OF THE FOUR. Measured: a descriptor with 7 / low / serial / 9 set copies to
// 7 / low / serial / 0 - Apple's own -copyWithZone: does not carry maxCommandsInFlight, and this one
// does the same rather than being more faithful than the release is. The scratch buffer allocator is
// carried and read back; no release and no object of this port makes an object conforming to
// MTLIOScratchBufferAllocator, so a caller setting one is setting its own, and a fresh descriptor
// reads nil on both sides.
//
// THE QUEUE ITSELF IS NOT HERE, and that is what this row has to say. `-[MTLDevice
// newIOQueueWithDescriptor:error:]` needs an MTLIOCommandBuffer that loads a file's bytes into a
// buffer the GPU reads, on hardware with a bindless resource path; the A7 this port targets has
// neither, and the port carries no IO command buffer, no IO file handle and no scratch buffer
// allocator. So there is no object to hand this descriptor to, and MTLIOCommandQueue is absent with
// that reason rather than with this one.
@implementation MTLIOCommandQueueDescriptor {
    NSUInteger _maxCommandBufferCount;
    MTLIOPriority _priority;
    MTLIOCommandQueueType _type;
    NSUInteger _maxCommandsInFlight;
    id<MTLIOScratchBufferAllocator> _scratchBufferAllocator;
}

@synthesize maxCommandBufferCount = _maxCommandBufferCount;
@synthesize priority = _priority;
@synthesize type = _type;
@synthesize maxCommandsInFlight = _maxCommandsInFlight;
@synthesize scratchBufferAllocator = _scratchBufferAllocator;

- (instancetype)init
{
    if ((self = [super init])) {
        _maxCommandBufferCount = 64;
        _priority = MTLIOPriorityNormal;
        _type = MTLIOCommandQueueTypeConcurrent;
        _maxCommandsInFlight = 0;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLIOCommandQueueDescriptor *copy = [[MTLIOCommandQueueDescriptor alloc] init];
    copy.maxCommandBufferCount = _maxCommandBufferCount;
    copy.priority = _priority;
    copy.type = _type;
    copy.scratchBufferAllocator = _scratchBufferAllocator;
    return copy;
}

@end
