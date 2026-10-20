#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import "RevenantMetal26Types.h"

static BOOL RevenantMetal4AttachmentBaseEqual(MTLRenderPassAttachmentDescriptor *mine,
                                             MTLRenderPassAttachmentDescriptor *theirs)
{
    if (mine.texture != theirs.texture && ![mine.texture isEqual:theirs.texture]) return NO;
    if (mine.level != theirs.level) return NO;
    if (mine.slice != theirs.slice) return NO;
    if (mine.loadAction != theirs.loadAction) return NO;
    if (mine.storeAction != theirs.storeAction) return NO;
    return YES;
}

static NSUInteger RevenantMetal4AttachmentBaseHash(MTLRenderPassAttachmentDescriptor *mine)
{
    NSUInteger hash = (NSUInteger)object_getClass(mine);
    hash = hash * 31u + (uint32_t)[mine.texture hash];
    hash = hash * 31u + (uint32_t)mine.level;
    hash = hash * 31u + (uint32_t)mine.slice;
    hash = hash * 31u + (uint32_t)mine.loadAction;
    hash = hash * 31u + (uint32_t)mine.storeAction;
    return hash;
}

enum { RevenantMetal4SamplePositions = 8 };

static BOOL RevenantMetal4SampleCountIsValid(NSUInteger count)
{
    return count == 0 || count == 2 || count == 4 || count == 8;
}

static BOOL RevenantMetal4CoordinateIsInRange(float value)
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
    MTLSamplePosition _samplePositions[RevenantMetal4SamplePositions];
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

- (void)setSamplePositions:(const MTLSamplePosition *)positions count:(NSUInteger)count
{
    if (!RevenantMetal4SampleCountIsValid(count)) {
        [NSException raise:NSInvalidArgumentException
                    format:@"setSamplePositions:count:%lu: a custom sample position count must be 0, 2, 4 or 8",
                           (unsigned long)count];
        return;
    }
    if (positions)
        for (NSUInteger index = 0; index < count; index++) {
            if (!RevenantMetal4CoordinateIsInRange(positions[index].x))
                [NSException raise:NSInvalidArgumentException
                            format:@"setSamplePositions:count:%lu: sample position %lu has x-coodicate %f, which is not within the range [0,1)",
                                   (unsigned long)count, (unsigned long)index, positions[index].x];
            if (!RevenantMetal4CoordinateIsInRange(positions[index].y))
                [NSException raise:NSInvalidArgumentException
                            format:@"setSamplePositions:count:%lu: sample position %lu has y-coodicate %f, which is not within the range [0,1)",
                                   (unsigned long)count, (unsigned long)index, positions[index].y];
        }
    if (!positions)
        return;
    if (count == 0) {
        _samplePositionCount = 0;
        return;
    }
    memcpy(_samplePositions, positions, count * sizeof(MTLSamplePosition));
    _samplePositionCount = count;
}

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
    if (!RevenantMetal4AttachmentBaseEqual(self.depthAttachment, theirs.depthAttachment)) return NO;
    if (self.depthAttachment.clearDepth != theirs.depthAttachment.clearDepth) return NO;
    if (!RevenantMetal4AttachmentBaseEqual(self.stencilAttachment, theirs.stencilAttachment)) return NO;
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
    hash = hash * 31u + (uint32_t)RevenantMetal4AttachmentBaseHash(self.depthAttachment);
    hash = hash * 31u + (uint32_t)(uint64_t)self.depthAttachment.clearDepth;
    hash = hash * 31u + (uint32_t)RevenantMetal4AttachmentBaseHash(self.stencilAttachment);
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
