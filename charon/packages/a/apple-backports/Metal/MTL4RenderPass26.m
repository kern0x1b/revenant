#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import "CharonMetal26Types.h"

// THE METAL 4 RENDER PASS DESCRIPTOR, and it is the same kind of thing as the twenty-four classes
// beside it: a data holder that says what a pass is over and asks the device nothing.
//
// EVERY DEFAULT BELOW IS APPLE'S OWN, measured against a fresh object of Apple's class, and they are
// all zeros, nils and one NO - which is worth saying because it is the answer a reader would guess and
// this file measured it anyway: the colour attachments, the depth attachment and the stencil
// attachment are OBJECTS on a fresh pass, the rasterization rate map and the visibility result buffer
// are nil, and the colour attachment array is the SAME eight-slot array MTLRenderPassDescriptor's own
// uses (measured: Apple's own array answers indices 0 to 7 and index 8 fails the framework's
// assertion, out of process).
//
// WHAT A COMMAND ENCODER WOULD DO WITH ONE OF THESE IS NOT HERE, and that is the same half
// facts/Metal/Descriptors26.md records: this port vends no MTL4CommandQueue and no MTL4CommandBuffer,
// so an application that fills one gets an object it can read, copy and compare - and no object to
// hand it to.

// THE SAMPLE POSITIONS, which are the one member here that is an ARRAY rather than a number, and the
// two methods are its reader and its writer. Metal's own bound is the sample count, and the header
// says a `count` of 0 disables custom positions; the port keeps as many as it is given and refuses to
// write past its own storage rather than reading past the caller's.
// THE TWO SINGLE ATTACHMENTS ARE COMPARED MEMBER BY MEMBER HERE, and that is a measurement: neither
// MTLRenderPassDepthAttachmentDescriptor nor MTLRenderPassStencilAttachmentDescriptor carries an
// -isEqual: of its own - measured, their own method lists have neither it nor -hash - yet two fresh
// ones ARE equal on Apple's side and changing one's clearDepth makes them DIFFER. So Apple's render
// pass equality compares the members itself, and so does this one.
//
// THE COLOUR ATTACHMENTS ARE NOT COMPARED AT ALL, and that is measured the other way: Apple's
// MTLRenderPassColorAttachmentDescriptorArray carries no -isEqual: either, two fresh arrays are NOT
// equal, and two fresh MTL4RenderPassDescriptors ARE equal. An equality that compared the attachments
// could not answer that - the same shape as the tile pipeline's array, and for the same measured reason.
static BOOL CharonMetal4AttachmentBaseEqual(MTLRenderPassAttachmentDescriptor *mine,
                                             MTLRenderPassAttachmentDescriptor *theirs)
{
    if (mine.texture != theirs.texture && ![mine.texture isEqual:theirs.texture]) return NO;
    if (mine.level != theirs.level) return NO;
    if (mine.slice != theirs.slice) return NO;
    if (mine.loadAction != theirs.loadAction) return NO;
    if (mine.storeAction != theirs.storeAction) return NO;
    return YES;
}

static NSUInteger CharonMetal4AttachmentBaseHash(MTLRenderPassAttachmentDescriptor *mine)
{
    NSUInteger hash = (NSUInteger)object_getClass(mine);
    hash = hash * 31u + (uint32_t)[mine.texture hash];
    hash = hash * 31u + (uint32_t)mine.level;
    hash = hash * 31u + (uint32_t)mine.slice;
    hash = hash * 31u + (uint32_t)mine.loadAction;
    hash = hash * 31u + (uint32_t)mine.storeAction;
    return hash;
}

// THREE BOUNDS, ALL REFUSED THE SAME WAY, AND ALL THREE MEASURED off Apple's own assertions rather than
// read off the header. The earlier version of this file claimed three and ENFORCED ONE, which was the
// defect worth fixing here:
//
//   * THE COUNT MUST BE A VALID SAMPLE COUNT. Apple's own words: "count (3) is not a supported sample
//     count for custom positions. count must be 0, 2, 4 or 8." That is what MTL4RenderPass.h:107 means
//     by "This value needs to be a valid sample count".
//   * BOTH COORDINATES LIE IN [0, 1). Two separate assertions, one per axis, each captured from the
//     framework's own stderr and each with its own line number: x-coodicate (1.500000) at index 1 at
//     line 433, y-coodicate (1.500000) at index 1 at line 435. A negative coordinate is out of range at
//     the bottom of the interval and 1.5 at the top.
//   * A READ'S COUNT MUST MATCH WHAT IS PROGRAMMED. Apple's own words: "Non-zero count (2) does not match
//     the number of programmed custom sample positions (4)" - measured for a count SMALLER than the
//     programmed one as well as a larger one, and both are the same assertion. A count of ZERO is the
//     one that is always allowed: it is how a caller asks how many there are without room for them.
//
// Every one of them is refused the way the eight-slot arrays are refused: an NSException whose reason
// names the bound and the value. Metal's own refusals are assertions that stop the process, so the
// differential asks them OUT OF PROCESS and compares what each side printed - see
// tests/backports/host/metal-census/descriptors26-samplebounds.{m,sh}.
enum { CharonMetal4SamplePositions = 8 };

static BOOL CharonMetal4SampleCountIsValid(NSUInteger count)
{
    return count == 0 || count == 2 || count == 4 || count == 8;
}

static BOOL CharonMetal4CoordinateIsInRange(float value)
{
    return value >= 0.0f && value < 1.0f;
}

@implementation MTL4RenderPassDescriptor {
    MTLRenderPassColorAttachmentDescriptorArray *_colorAttachments;
    MTLRenderPassDepthAttachmentDescriptor *_depthAttachment;
    MTLRenderPassStencilAttachmentDescriptor *_stencilAttachment;
    NSUInteger _renderTargetArrayLength;
    NSUInteger _imageblockSampleLength;
    NSUInteger _threadgroupMemoryLength;
    NSUInteger _tileWidth;
    NSUInteger _tileHeight;
    NSUInteger _defaultRasterSampleCount;
    NSUInteger _renderTargetWidth;
    NSUInteger _renderTargetHeight;
    id<MTLRasterizationRateMap> _rasterizationRateMap;
    id<MTLBuffer> _visibilityResultBuffer;
    MTLVisibilityResultType _visibilityResultType;
    BOOL _supportColorAttachmentMapping;
    MTLSamplePosition _samplePositions[CharonMetal4SamplePositions];
    NSUInteger _samplePositionCount;
}

@synthesize colorAttachments = _colorAttachments;
@synthesize depthAttachment = _depthAttachment;
@synthesize stencilAttachment = _stencilAttachment;
@synthesize renderTargetArrayLength = _renderTargetArrayLength;
@synthesize imageblockSampleLength = _imageblockSampleLength;
@synthesize threadgroupMemoryLength = _threadgroupMemoryLength;
@synthesize tileWidth = _tileWidth;
@synthesize tileHeight = _tileHeight;
@synthesize defaultRasterSampleCount = _defaultRasterSampleCount;
@synthesize renderTargetWidth = _renderTargetWidth;
@synthesize renderTargetHeight = _renderTargetHeight;
@synthesize rasterizationRateMap = _rasterizationRateMap;
@synthesize visibilityResultBuffer = _visibilityResultBuffer;
@synthesize visibilityResultType = _visibilityResultType;
@synthesize supportColorAttachmentMapping = _supportColorAttachmentMapping;

// The three attachment OBJECTS are made here rather than left to a getter that would answer nil,
// because that is what Apple's own fresh object answers - measured. Everything else is its own zero.
- (instancetype)init
{
    if ((self = [super init])) {
        _colorAttachments = [[MTLRenderPassColorAttachmentDescriptorArray alloc] init];
        _depthAttachment = [[MTLRenderPassDepthAttachmentDescriptor alloc] init];
        _stencilAttachment = [[MTLRenderPassStencilAttachmentDescriptor alloc] init];
    }
    return self;
}

- (void)setDepthAttachment:(MTLRenderPassDepthAttachmentDescriptor *)depthAttachment
{
    _depthAttachment = [depthAttachment copy];
}

- (void)setStencilAttachment:(MTLRenderPassStencilAttachmentDescriptor *)stencilAttachment
{
    _stencilAttachment = [stencilAttachment copy];
}

// THE HEADER'S OWN CONTRACT for the two, and then what the MEASUREMENT says where the two differ.
// MTL4RenderPass.h:108 says setSamplePositions:count: takes the positions and how many there are, with
// zero disabling custom sample positions; :113 says getSamplePositions:count: writes the app's last set positions
// into an output array, and that it writes into the array only if the count argument is big enough to hold them.
//
// THE HEADER'S "SUFFICIENT TO STORE" IS NOT WHAT METAL DOES, and the comment that used to stand here
// said the opposite - that a read into a buffer too small would change nothing - which my own
// measurement refutes. Measured, against Apple's own object, out of process: with four positions
// programmed, a read with a count of 2 asserts "Non-zero count (2) does not match the number of
// programmed custom sample positions (4)". A count SMALLER than what is programmed is refused exactly
// as a larger one is, and the only count that is always allowed is zero. So the two methods below
// refuse three bounds rather than one, and the third of them is that read.
- (void)setSamplePositions:(const MTLSamplePosition *)positions count:(NSUInteger)count
{
    if (!CharonMetal4SampleCountIsValid(count)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"setSamplePositions:count:%lu: a custom sample position count must be 0, 2, 4 or 8",
                           (unsigned long)count];
        return;
    }
    // THE COORDINATES, per axis and with the INDEX in the message, because Apple's own assertion names
    // the index and this is the one a reader debugging a sampler would look for.
    if (positions)
        for (NSUInteger index = 0; index < count; index++) {
            if (!CharonMetal4CoordinateIsInRange(positions[index].x))
                [NSException raise:NSInvalidArgumentException
                            format:@"setSamplePositions:count:%lu: sample position %lu has x-coodicate %f, which is not within the range [0,1)",
                                   (unsigned long)count, (unsigned long)index, positions[index].x];
            if (!CharonMetal4CoordinateIsInRange(positions[index].y))
                [NSException raise:NSInvalidArgumentException
                            format:@"setSamplePositions:count:%lu: sample position %lu has y-coodicate %f, which is not within the range [0,1)",
                                   (unsigned long)count, (unsigned long)index, positions[index].y];
        }
    // A NULL POINTER STORES NOTHING, and that is measured rather than guessed: with two positions
    // programmed, -setSamplePositions:NULL count:0 leaves the object holding TWO, while the same call
    // with a non-NULL pointer and count 0 leaves it holding NONE - which is what MTL4RenderPass.h:107
    // means by "or 0 to disable custom sample positions". So the two cases are different and this is
    // where they differ.
    if (!positions)
        return;
    if (count == 0) {
        _samplePositionCount = 0;
        return;
    }
    memcpy(_samplePositions, positions, count * sizeof(MTLSamplePosition));
    _samplePositionCount = count;
}

// AND THE READ, whose bound is the same shape as the other two: a count of zero asks how many there
// are and is always allowed, and any OTHER count must be exactly what is programmed - measured for a
// count smaller than the programmed one as well as a larger one, because the first version of this
// method accepted anything and claimed to follow the header's "a length sufficient to store".
- (NSUInteger)getSamplePositions:(MTLSamplePosition *)positions count:(NSUInteger)count
{
    if (count != 0 && count != _samplePositionCount) {
        [NSException raise:NSInvalidArgumentException
                    format:@"getSamplePositions:count:%lu: a non-zero count must match the %lu programmed custom sample position(s)",
                           (unsigned long)count, (unsigned long)_samplePositionCount];
        return 0;
    }
    if (positions && count == _samplePositionCount && count != 0)
        memcpy(positions, _samplePositions, _samplePositionCount * sizeof(MTLSamplePosition));
    return _samplePositionCount;
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[MTL4RenderPassDescriptor class]]) return NO;
    MTL4RenderPassDescriptor *theirs = object;
    // The colour attachments are NOT a member of this comparison, for the measured reason above.
    if (!CharonMetal4AttachmentBaseEqual(self.depthAttachment, theirs.depthAttachment)) return NO;
    if (self.depthAttachment.clearDepth != theirs.depthAttachment.clearDepth) return NO;
    if (!CharonMetal4AttachmentBaseEqual(self.stencilAttachment, theirs.stencilAttachment)) return NO;
    if (self.stencilAttachment.clearStencil != theirs.stencilAttachment.clearStencil) return NO;
    if (self.renderTargetArrayLength != theirs.renderTargetArrayLength) return NO;
    if (self.imageblockSampleLength != theirs.imageblockSampleLength) return NO;
    if (self.threadgroupMemoryLength != theirs.threadgroupMemoryLength) return NO;
    if (self.tileWidth != theirs.tileWidth) return NO;
    if (self.tileHeight != theirs.tileHeight) return NO;
    if (self.defaultRasterSampleCount != theirs.defaultRasterSampleCount) return NO;
    if (self.renderTargetWidth != theirs.renderTargetWidth) return NO;
    if (self.renderTargetHeight != theirs.renderTargetHeight) return NO;
    if (self.rasterizationRateMap != theirs.rasterizationRateMap && ![self.rasterizationRateMap isEqual:theirs.rasterizationRateMap]) return NO;
    if (self.visibilityResultBuffer != theirs.visibilityResultBuffer && ![self.visibilityResultBuffer isEqual:theirs.visibilityResultBuffer]) return NO;
    if (self.visibilityResultType != theirs.visibilityResultType) return NO;
    if (self.supportColorAttachmentMapping != theirs.supportColorAttachmentMapping) return NO;
    if (_samplePositionCount != theirs->_samplePositionCount) return NO;
    for (NSUInteger index = 0; index < _samplePositionCount; index++)
        if (memcmp(&_samplePositions[index], &theirs->_samplePositions[index], sizeof(MTLSamplePosition)) != 0)
            return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)object_getClass(self);
    hash = hash * 31u + (uint32_t)CharonMetal4AttachmentBaseHash(self.depthAttachment);
    hash = hash * 31u + (uint32_t)(uint64_t)self.depthAttachment.clearDepth;
    hash = hash * 31u + (uint32_t)CharonMetal4AttachmentBaseHash(self.stencilAttachment);
    hash = hash * 31u + (uint32_t)self.stencilAttachment.clearStencil;
    hash = hash * 31u + (uint32_t)self.renderTargetArrayLength;
    hash = hash * 31u + (uint32_t)self.imageblockSampleLength;
    hash = hash * 31u + (uint32_t)self.threadgroupMemoryLength;
    hash = hash * 31u + (uint32_t)self.tileWidth;
    hash = hash * 31u + (uint32_t)self.tileHeight;
    hash = hash * 31u + (uint32_t)self.defaultRasterSampleCount;
    hash = hash * 31u + (uint32_t)self.renderTargetWidth;
    hash = hash * 31u + (uint32_t)self.renderTargetHeight;
    hash = hash * 31u + (uint32_t)[self.rasterizationRateMap hash];
    hash = hash * 31u + (uint32_t)[self.visibilityResultBuffer hash];
    hash = hash * 31u + (uint32_t)self.visibilityResultType;
    hash = hash * 31u + (uint32_t)self.supportColorAttachmentMapping;
    hash = hash * 31u + (uint32_t)_samplePositionCount;
    return hash;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTL4RenderPassDescriptor *copy = [[MTL4RenderPassDescriptor alloc] init];
    copy.renderTargetArrayLength = self.renderTargetArrayLength;
    copy.imageblockSampleLength = self.imageblockSampleLength;
    copy.threadgroupMemoryLength = self.threadgroupMemoryLength;
    copy.tileWidth = self.tileWidth;
    copy.tileHeight = self.tileHeight;
    copy.defaultRasterSampleCount = self.defaultRasterSampleCount;
    copy.renderTargetWidth = self.renderTargetWidth;
    copy.renderTargetHeight = self.renderTargetHeight;
    copy.rasterizationRateMap = self.rasterizationRateMap;
    copy.visibilityResultBuffer = self.visibilityResultBuffer;
    copy.visibilityResultType = self.visibilityResultType;
    copy.supportColorAttachmentMapping = self.supportColorAttachmentMapping;
    copy.depthAttachment = self.depthAttachment;
    copy.stencilAttachment = self.stencilAttachment;
    [copy setSamplePositions:_samplePositionCount ? _samplePositions : NULL count:_samplePositionCount];
    return copy;
}

@end