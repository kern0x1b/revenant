#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
// THE PROTOCOL'S TWO COMMITS ARE NOT IN THIS FILE, and clang says so - twice, once per method - because this
// class adopts @protocol MTL4CommandQueue and their rows -[MTL4CommandQueue commit:count:] and
// -[MTL4CommandQueue commit:count:options:] are `owed` until Metal/MTL4CommandBuffer26.m exists. **Those two
// warnings are the truth and they stay visible**: they are how a reader of a build log sees that two required
// members of an adopted protocol are owed, and the wave's rule is that no new diagnostic pragma goes into a
// port file. The gate counts errors and a warning is not one - land-w14 went through with four of the same
// warning in MetalPerformanceShaders/MPSGraphExecutionDescriptor14.m - so nothing here is silenced to make a
// check pass. Defining either commit now would be the thing to hide: every buffer a caller could hand it would
// be refused, which is a row claiming work the port cannot do.
#import "CharonMetal.h"
#import "CharonMetal26Types.h"
// THE TRANSCRIBED @protocol MTL4CommandQueue, which the 16.4 SDK this file compiles against does not
// declare and which the class below adopts: facts only, written by tools/gen.lua protocols (the port of tools/transcribe-protocols.py@52253c0650).
#import "CharonMetalProtocols.h"

// THE METAL 4 QUEUE, over the port's own CharonMetalQueue, which is the queue that works: it holds the
// EAGL context over OpenGL ES 2.0 that every draw in this port goes through. So a Metal 4 caller asking
// for a Metal 4 queue gets the same working queue a Metal 3 caller gets, with the two members the rows
// name on top. That is what makes the row honest - there is ONE queue in this port and it is the one
// that runs - and it is why this class adds members and not behaviour.
//
// It is a class rather than a conformance to @protocol MTL4CommandQueue because iOS 6 has no Metal 4
// protocol to conform to: the 26.2 headers declare the protocol and the surface's rows for its members
// are the class's.
//
// THE TWELVE MEMBERS BELOW ARE SORTED BY WHAT THIS BACKEND ACTUALLY IS, because a member that logs
// "refused" and returns is a stub and a row that calls that `implemented` is a row contradicting itself.
// Four groups, each with the facts line that puts its member where it is:
//
//  (a) **THE NO-OP IS THE RIGHT ANSWER, and it says nothing.** The four residency-set members and the two
//      drawable members. Every resource of this port is CPU-resident whatever the application asked for -
//      a buffer is its own bytes and a texture is read and written on the CPU
//      (facts/Metal/Blits.md, "The access hints", and facts/Metal/Heaps.md, "Hazard tracking and storage
//      modes") - so there is no residency a set could add and none it could take away, and a draw is a
//      call into OpenGL ES 2.0 that has already been made by the time it is encoded, so a drawable is
//      never waiting for anything and never waiting to be told. The header of `-waitForDrawable:` says that the call returns at once and
//      takes no lock on the current thread,
//      which is what this body is; `-signalDrawable:` schedules the signal that says rendering is
//      complete, and on this backend it already is. This is the same shape as
//      `-[MTLCommandBuffer optimizeContentsForCPUAccess:]` in facts/Metal/Blits.md: doing nothing,
//      because the performance it asks for is already the case. These rows are `implemented` and NO
//      member here prints a line.
//
//  (b) **DONE NATIVELY OVER THE PORT'S OWN OBJECTS.** `-signalEvent:value:` and `-waitForEvent:value:`,
//      over `CharonMetalSharedEvent`, whose state is a signalled value and a wait that blocks until it is
//      reached (Metal/MTLSharedEvent12.m). @protocol MTLSharedEvent is declared as a refinement of
//      MTLEvent in the 26.2 SDK (MTLEvent.h:52), so the port's own event IS an MTLEvent by shape. A GPU
//      event is signalled when the work before it is complete, and here the work before it is complete
//      by the time the call is encoded, for the same reason the hazard tracking above is not acted on.
//      These rows are `implemented` and the probe asks both of them on the guest.
//
//  (c) **REFUSED AS METAL REFUSES THEM.** The four sparse mapping members. A sparse mapping needs a
//      placement sparse buffer or texture and a placement heap, and the port makes neither, so every call
//      is refused by the requirement Metal's own assertion names (facts/Metal/SparseMapping26.md, where the
//      refusals are measured on the macOS 26 host). The reasons come from MTL4SparseMapping26.m, and the
//      raise is an NSInternalInconsistencyException, which ends an uncaught process as Metal's assertion does.
//
// facts/Metal/RenderPath.md is where the rendering path says what it does, and
// facts/Metal/CommandChain26.md is where the expectations and the runs live.
//
// **TWELVE OF THE PROTOCOL'S OWN MEMBERS ARE ON THIS CLASS, and they were on the DEVICE until the device
// probe found it.** Every method from -commit:count: down used to be written in the CharonMetalDevice
// category below, so all fourteen of them answered on the DEVICE and none on the queue - and a Metal 4
// caller holds a queue. Twelve are here now; the two commits are not, because they need a buffer this port
// does not carry, and the reason is at their place in the declaration below. It was found by running and
// not by reading: the device probe's case
// metalchain_commit_returns asks the queue for -commit:count: and the run of 2026-10-04 answered
// "FAIL metalchain_commit_returns: the queue answers -commit:count: (Apple's own queue does)", while the
// binary's own symbol table carries -[CharonMetalDevice(CharonMetal4CommandQueue26) commit:count:] and
// nothing of that name on the queue (tests/backports/device/metalchain-probe/run/run.log). The ledger
// agrees and was not guessing: all fourteen were status `missing` - they are the queue's members, so with
// none of them on the queue the queue did not exist as far as the corpus was concerned.
// **THE CLASS CONFORMS TO @protocol MTL4CommandQueue, and that is what makes the ten member rows
// answerable.** iOS 6 has no Metal 4 protocol to adopt, so the declaration is transcribed from the SDK that
// has it into CharonMetalProtocols.h (tools/gen.lua protocols, facts only), and this conformance is
// what makes clang emit __OBJC_PROTOCOL_$_MTL4CommandQueue with the protocol's method list into this object.
// The corpus asks for exactly that: MTL4CommandQueue is a `header-ok`, `needs lift` row. Without it the
// methods are the port's own names on a Charon* class and every row naming the protocol is a row nothing
// answers for - measured 2026-10-04, when the landing gate failed all ten with "listed as implemented, but
// nothing of that name is built" (the eight members below plus MTL4CommandQueue.device and .label).
// The generated per-band source MetalBackportsProtocols26.m then finds this conformance and does NOT force
// the object, which is the duplicate check modules/apple/backports.lua makes.
@interface CharonMetal4CommandQueue : NSObject <MTL4CommandQueue>
// THE LABEL IS READONLY AND ATOMIC, which is what MTL4CommandQueue.h:218 declares - `@property (readonly,
// nullable) NSString* label` - and atomic is the default a property has, so that is the spelling that matches
// the protocol's own and not a copy and not nonatomic. The label therefore arrives the way Metal 4 says it
// does, through the descriptor, and there is no setter for a caller to reach; -charonSetLabel: is the port's
// own seam for the one place that sets it, the same shape as -[MTLFunction charonCheckHeapOf:what:] and
// -[UIPasteboard charonRecordOptions:] and carrying its own registry row.
@property (atomic, readonly) NSString *label;
- (void)charonSetLabel:(NSString *)label;
// **-commit:count: AND -commit:count:options: ARE NOT HERE, and that is a dependency and not an
// oversight.** Both take an array of MTL4CommandBuffer, and this port carries no MTL4CommandBuffer: the
// buffer is the next family (Metal/MTL4CommandBuffer26.m does not exist yet) and every buffer a Metal 4
// caller could hand the commit would be "not one of this port's". A method that answers wrongly is worse
// than one that is absent, so the two rows -[MTL4CommandQueue commit:count:] and
// -[MTL4CommandQueue commit:count:options:] are status `owed` with the reason "waits on the
// MTL4CommandBuffer family", and check_registry holds a row that is not `implemented` to an answer the
// build does not give ("listed as absent, but what is built answers it"). They come back with the buffer.
- (void)addResidencySet:(id)residencySet;
- (void)removeResidencySet:(id)residencySet;
- (void)addResidencySets:(const id *)sets count:(NSUInteger)count;
- (void)removeResidencySets:(const id *)sets count:(NSUInteger)count;
// THE SPARSE FOUR ARE SPELLED AS MTL4CommandQueue.h SPELLS THEM - `heap:operations:count:` and four
// parameters, not the three and `heap:count:` of the first version of this file, which the corpus never
// named and the landing gate of 2026-10-04 would have failed the same way it failed the rows.
- (void)updateBufferMappings:(id<MTLBuffer>)buffer heap:(id<MTLHeap>)heap
                  operations:(const MTL4UpdateSparseBufferMappingOperation *)operations count:(NSUInteger)count;
- (void)updateTextureMappings:(id<MTLTexture>)texture heap:(id<MTLHeap>)heap
                   operations:(const MTL4UpdateSparseTextureMappingOperation *)operations count:(NSUInteger)count;
- (void)copyBufferMappingsFromBuffer:(id<MTLBuffer>)source toBuffer:(id<MTLBuffer>)destination
                           operations:(const MTL4CopySparseBufferMappingOperation *)operations count:(NSUInteger)count;
- (void)copyTextureMappingsFromTexture:(id<MTLTexture>)source toTexture:(id<MTLTexture>)destination
                              operations:(const MTL4CopySparseTextureMappingOperation *)operations count:(NSUInteger)count;
- (void)waitForDrawable:(id<MTLDrawable>)drawable;
// MTL4CommandQueue.h:274 and :308 spell the event `id<MTLEvent>`, and it is spelled `id` here: iOS 6 has
// no MTLEvent for the port to name, the SDK annotates the type as 12.0 and later, and naming it would
// warn on every build of this file for a method that refuses the call anyway. The selector is the one
// the header declares, which is what a caller and the registry both see.
- (void)waitForEvent:(id)event value:(uint64_t)value;
- (void)signalEvent:(id)event value:(uint64_t)value;
- (void)signalDrawable:(id<MTLDrawable>)drawable;
@end

// The sparse mapping refusals, decided in MTL4SparseMapping26.m beside the reasons Metal gives.
NSString *CharonMetal4SparseBufferUpdateRefusal(BOOL bufferIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode);
NSString *CharonMetal4SparseBufferCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse);
NSString *CharonMetal4SparseTextureUpdateRefusal(BOOL textureIsPlacementSparse, BOOL heapPresent, BOOL heapIsPlacement, BOOL mappingMode);
NSString *CharonMetal4SparseTextureCopyRefusal(BOOL sourceIsPlacementSparse, BOOL destinationIsPlacementSparse);

// A resource is placement sparse when it answers placementSparsePageSize (a macOS 26 property, absent from the
// iOS 16.4 headers this package compiles against). The port's buffers and textures never answer it: the port
// makes none, so the question is asked and the answer is no.
static BOOL CharonMetal4IsPlacementSparse(id resource)
{
    return [resource respondsToSelector:NSSelectorFromString(@"placementSparsePageSize")];
}

// Metal's refusal is an assertion, which ends the process; the port raises the same text as an
// NSInternalInconsistencyException, which ends an uncaught process the same way. The fallback is the one
// reason that holds for every resource this port has: a call whose requirements all hold has still nothing
// to map to, because the port makes no placement sparse resource, so it is refused and not accepted.
static void CharonMetal4RaiseSparseRefusal(NSString *reason)
{
    [NSException raise:NSInternalInconsistencyException
                format:@"%@", reason ?: @"a sparse mapping is not performed on this device: no resource of this port is placement sparse"];
}

@implementation CharonMetal4CommandQueue {
    CharonMetalQueue *_queue;
    NSString *_label;
}

- (instancetype)init
{
    if ((self = [super init]))
        _queue = [[CharonMetalQueue alloc] init];
    return self;
}

// THE PORT'S OWN DEVICE, which is what a Metal 3 caller is told too: this port has one device and it is
// the shared one. The queue it answers with is the queue's own -device, not a fresh one, so the two
// agree by construction rather than by two lookups that could differ.
- (id<MTLDevice>)device
{
    return [_queue device];
}

// NIL ON A FRESH QUEUE, measured against Apple's own object and written down in
// tests/backports/device/metalchain-expectations.h as metalchain_queue_label_is_nil. The label is COPIED
// and is the queue's own string, so labelling a Metal 4 queue does not touch the Metal 3 one behind it.
- (NSString *)label
{
    return _label;
}

- (void)charonSetLabel:(NSString *)label
{
    _label = [label copy];
}

// (a) THE RESIDENCY SETS, and the no-op is the answer rather than a stub: a residency set asks the driver
// to keep a set of resources resident for the buffers of this queue, and every resource of this port is
// CPU-resident for the life of its EAGL context whatever the application asked for - a buffer is its own
// bytes and a texture is read and written on the CPU (facts/Metal/Blits.md, "The access hints"). There
// is nothing to make resident and nothing to unmake it from, so the correct answer on this backend is
// that the state the call would change is already the case. These are `implemented` rows and they say
// nothing at all: a caller that added a set and heard a refusal would be told its resources are not
// resident, which on this port is false.
- (void)addResidencySet:(id)residencySet
{
    (void)residencySet;
}

- (void)removeResidencySet:(id)residencySet
{
    (void)residencySet;
}

- (void)addResidencySets:(const id *)sets count:(NSUInteger)count
{
    (void)sets;
    (void)count;
}

- (void)removeResidencySets:(const id *)sets count:(NSUInteger)count
{
    (void)sets;
    (void)count;
}

// (c) THE SPARSE MAPPINGS, refused as Metal refuses them. A sparse mapping needs a placement sparse buffer or
// texture and a placement heap, and the port makes neither (facts/Metal/SparseMapping26.md). Metal's own
// refusals are measured there, and the reasons are the ones MTL4SparseMapping26.m returns; a call whose
// requirements hold is refused too, because nothing of this port can be mapped. None of these returns: the
// mapping is refused by name, so no caller is told that a mapping happened.
//
// The operations are not read here: this SDK's operation structs are forward-declared by the generated protocol
// header, so their fields cannot be read from this file. No buffer or texture of this port is placement sparse, so
// the first check refuses every call and the mapping mode is never consulted. The flag is passed as a mapping, which
// is what a call with operations to perform is.
- (void)updateBufferMappings:(id<MTLBuffer>)buffer heap:(id<MTLHeap>)heap
                  operations:(const MTL4UpdateSparseBufferMappingOperation *)operations count:(NSUInteger)count
{
    CharonMetal4RaiseSparseRefusal(CharonMetal4SparseBufferUpdateRefusal(CharonMetal4IsPlacementSparse(buffer), heap != nil,
                                                                         heap != nil && heap.type == MTLHeapTypePlacement,
                                                                         YES));
}

- (void)updateTextureMappings:(id<MTLTexture>)texture heap:(id<MTLHeap>)heap
                   operations:(const MTL4UpdateSparseTextureMappingOperation *)operations count:(NSUInteger)count
{
    CharonMetal4RaiseSparseRefusal(CharonMetal4SparseTextureUpdateRefusal(CharonMetal4IsPlacementSparse(texture), heap != nil,
                                                                           heap != nil && heap.type == MTLHeapTypePlacement,
                                                                           YES));
}

- (void)copyBufferMappingsFromBuffer:(id<MTLBuffer>)source toBuffer:(id<MTLBuffer>)destination
                           operations:(const MTL4CopySparseBufferMappingOperation *)operations count:(NSUInteger)count
{
    CharonMetal4RaiseSparseRefusal(CharonMetal4SparseBufferCopyRefusal(CharonMetal4IsPlacementSparse(source),
                                                                       CharonMetal4IsPlacementSparse(destination)));
}

- (void)copyTextureMappingsFromTexture:(id<MTLTexture>)source toTexture:(id<MTLTexture>)destination
                              operations:(const MTL4CopySparseTextureMappingOperation *)operations count:(NSUInteger)count
{
    CharonMetal4RaiseSparseRefusal(CharonMetal4SparseTextureCopyRefusal(CharonMetal4IsPlacementSparse(source),
                                                                        CharonMetal4IsPlacementSparse(destination)));
}

// (a) THE DRAWABLE PAIR, and here too the no-op is the answer rather than a stub. A drawable of this port
// is a texture already drawn into the EAGL framebuffer (Metal/CharonMetalDrawable.h's class, and
// facts/Metal/RenderPath.md for the path), and a draw is a call into OpenGL ES 2.0 that has already been
// made by the time it is encoded - the same fact facts/Metal/Heaps.md gives for hazard tracking. So the
// display is never using a drawable this port still needs back, and rendering to it is complete when the
// encoding returns. `-waitForDrawable:`'s own header says it returns immediately and performs no
// synchronization, and `-signalDrawable:` schedules a signal for a completion that has happened. Neither
// triggers the presentation, which is `-[MTLCommandQueue presentDrawable:]`'s own work and the
// application's to ask for.
- (void)waitForDrawable:(id<MTLDrawable>)drawable
{
    (void)drawable;
}

- (void)signalDrawable:(id<MTLDrawable>)drawable
{
    (void)drawable;
}

// (b) THE EVENTS, and these do real work over the port's own event. `CharonMetalSharedEvent` carries a
// state of its own: a signalled value, a setter for it, and a wait that blocks until the value is
// reached (Metal/MTLSharedEvent12.m), and @protocol MTLSharedEvent refines MTLEvent in the 26.2 SDK
// (MTLEvent.h:52), so the port's own event is an MTLEvent by shape.
//
// -signalEvent:value: takes effect once all earlier GPU work is done, and on this backend that
// work is complete by the time the call is encoded, so the value is set now rather than scheduled.
// -waitForEvent:value: blocks until the state reaches the value, which is what the same wait does for
// `-[MTLSharedEvent waitUntilSignaledValue:timeout:]`; a value that has already been reached returns at
// once. An event that is not one of the port's has no state to read or set, and that is refused by name:
// inventing a value on an object whose owner would never see it is worse than saying so.
- (void)signalEvent:(id)event value:(uint64_t)value
{
    if ([event isKindOfClass:[CharonMetalSharedEvent class]]) {
        [(CharonMetalSharedEvent *)event setSignaledValue:value];
        return;
    }
    NSLog(@"Metal: -signalEvent:value: was given a %@ and not one of this port's events, and a signalled value set on it would be a value nothing else could ever read",
          NSStringFromClass([event class]));
}

- (void)waitForEvent:(id)event value:(uint64_t)value
{
    if ([event isKindOfClass:[CharonMetalSharedEvent class]]) {
        [(CharonMetalSharedEvent *)event charonWaitForValue:value];
        return;
    }
    NSLog(@"Metal: -waitForEvent:value: was given a %@ and not one of this port's events, and there is no signalled value on it to wait for",
          NSStringFromClass([event class]));
}

@end

// THE DEVICE'S TWO METAL 4 FACTORIES, added where the device is rather than in this file, because an
// object carries the API of ONE release and CharonMetalDevice is 8.0's. Both hand back the same queue.
//
// AND NOTHING ELSE: every other member of @protocol MTL4CommandQueue is the QUEUE's and is on the queue
// above. A Metal 4 method on the device is one a Metal 4 caller cannot reach through the object it holds.
@interface CharonMetalDevice (CharonMetal4CommandQueue26)
- (id)newMTL4CommandQueue;
- (id)newMTL4CommandQueueWithDescriptor:(MTL4CommandQueueDescriptor *)descriptor error:(NSError **)error;
@end

@implementation CharonMetalDevice (CharonMetal4CommandQueue26)

// Metal 4's plain factory, MTLDevice.h:1262ff. Apple's own answers with a queue on this machine, and the
// queue's fresh label is nil - both measured and both in the expectations header.
- (id)newMTL4CommandQueue
{
    return [[CharonMetal4CommandQueue alloc] init];
}

// WITH A DESCRIPTOR, MTLDevice.h:1271, and this is Metal 4's: measured against Apple's own object, it
// answers with a queue and NO ERROR given a real MTL4CommandQueueDescriptor
// (metalchain_queue_from_descriptor_has_no_error). The descriptor's label is taken; its feedbackQueue is
// not, because this queue has no feedback to put on one - the port's feedback is the commit, and there is
// nowhere on a command queue here for it to report to.
- (id)newMTL4CommandQueueWithDescriptor:(MTL4CommandQueueDescriptor *)descriptor error:(NSError **)error
{
    CharonMetal4CommandQueue *queue = [[CharonMetal4CommandQueue alloc] init];
    [queue charonSetLabel:descriptor.label];
    return queue;
}

// THE WAIT IS NOT HERE ON THE DEVICE EITHER, and that is Apple's shape rather than a gap: Metal 4's
// queue has no -waitForCommandBuffers: (metalchain_queue_has_no_wait_for_command_buffers), its only
// waits being -waitForEvent:value: and -waitForDrawable:. So the device does not grow one either.
@end

// THE CAPTURE SCOPE OVER A METAL 4 QUEUE, which is the scope the port already makes over a Metal 3 one: a
// capture scope is a device and a queue, and this port's scope records both and starts nothing.
@interface MTLCaptureManager (CharonMetal4CaptureScope26)
- (id)newCaptureScopeWithMTL4CommandQueue:(id)commandQueue;
@end

@implementation MTLCaptureManager (CharonMetal4CaptureScope26)

- (id)newCaptureScopeWithMTL4CommandQueue:(id)commandQueue
{
    return [self newCaptureScopeWithCommandQueue:(id<MTLCommandQueue>)commandQueue];
}

@end
