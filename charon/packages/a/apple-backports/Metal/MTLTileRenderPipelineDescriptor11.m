#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "CharonMetal26Types.h"

// THE TILE RENDER PIPELINE DESCRIPTOR, the class MTLRenderPipeline.h declares at iOS 11.0.
//
// A plain data holder, like the compute descriptor beside it: it says what a tile pipeline is built from
// and asks no device anything. Nothing here hands back a pipeline state; the descriptor is carried so that
// a caller building one reads back what it wrote. Its colour attachments and tile buffers are the classes
// the port already carries (MTLTileRenderPipelineAttachments11.m and MTLReflection11.m).
//
// THE MEMBERS CARRY THE RELEASE THEY ARRIVED IN, and this file holds them all, as the 14.0 descriptors do.
// shaderValidation (18.0) and requiredThreadsPerThreadgroup (26.0) are declared for the port by
// CharonMetal26Types.h and implemented as explicit accessors here.
//
// FRESH DEFAULTS, measured on the host (tests/backports/host/tile-render-pipeline-descriptor):
//   * rasterSampleCount is 1; a fresh colour attachment's pixel format is MTLPixelFormatInvalid;
//   * tileBuffers answers a descriptor at slot 0; preloadedLibraries is an empty array; linkedFunctions is set;
//   * maxCallStackDepth is 1, shaderValidation is MTLShaderValidationDefault, and the required size is 0 x 0 x 0.
//
// -reset restores EVERY member, measured: the set rasterSampleCount, flags, threadgroup limit, required size,
// colour attachment and tile buffer all read back at their defaults. The two differences from a fresh
// descriptor are the library array, which reads nil after a reset (where a fresh one is empty), and the
// linked functions, which read a fresh object again.
//
// COPY is a deep copy of the nested objects: the copy owns its colour attachments, its tile buffers and its
// linked functions, and a value set in the original reads back in the copy.

// Apple's colour attachment array has 8 slots, and the attachment array class holds them (measured there).
static const NSUInteger CharonTileColorSlots = 8;
// Apple's buffer array has 31 slots, measured in MTLReflection11.m.
static const NSUInteger CharonTileBufferSlots = 31;

@implementation MTLTileRenderPipelineDescriptor {
    NSString *_label;
    id<MTLFunction> _tileFunction;
    NSUInteger _rasterSampleCount;
    MTLTileRenderPipelineColorAttachmentDescriptorArray *_colorAttachments;
    BOOL _threadgroupSizeMatchesTileSize;
    MTLPipelineBufferDescriptorArray *_tileBuffers;
    NSUInteger _maxTotalThreadsPerThreadgroup;
    NSArray *_binaryArchives;
    NSArray *_preloadedLibraries;
    MTLLinkedFunctions *_linkedFunctions;
    BOOL _supportAddingBinaryFunctions;
    NSUInteger _maxCallStackDepth;
    MTLShaderValidation _shaderValidation;
    MTLSize _requiredThreadsPerThreadgroup;
}

@synthesize label = _label;
@synthesize tileFunction = _tileFunction;
@synthesize rasterSampleCount = _rasterSampleCount;
@synthesize colorAttachments = _colorAttachments;
@synthesize threadgroupSizeMatchesTileSize = _threadgroupSizeMatchesTileSize;
@synthesize tileBuffers = _tileBuffers;
@synthesize maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
@synthesize binaryArchives = _binaryArchives;
@synthesize preloadedLibraries = _preloadedLibraries;
@synthesize supportAddingBinaryFunctions = _supportAddingBinaryFunctions;
@synthesize maxCallStackDepth = _maxCallStackDepth;

// A fresh descriptor: the defaults the reset gives, with the library array empty rather than nil.
- (instancetype)init
{
    if ((self = [super init])) {
        _colorAttachments = [[MTLTileRenderPipelineColorAttachmentDescriptorArray alloc] init];
        _tileBuffers = [[MTLPipelineBufferDescriptorArray alloc] init];
        [self reset];
        _preloadedLibraries = @[];
    }
    return self;
}

// Apple's -reset, measured: every member goes back to its default. The colour attachments array keeps its object
// across -reset, but its slots are new objects, so the slots do not keep their identity. The library array reads
// nil afterwards, and the linked functions are a fresh object. The tile buffers' identity is not measured: reading
// them before -reset crashes Apple (see facts/Metal/TileRenderPipelineDescriptor.md).
- (void)reset
{
    _label = nil;
    _tileFunction = nil;
    _rasterSampleCount = 1;
    for (NSUInteger slot = 0; slot < CharonTileColorSlots; slot++)
        _colorAttachments[slot] = nil;
    _threadgroupSizeMatchesTileSize = NO;
    for (NSUInteger slot = 0; slot < CharonTileBufferSlots; slot++)
        _tileBuffers[slot] = nil;
    _maxTotalThreadsPerThreadgroup = 0;
    _binaryArchives = nil;
    _preloadedLibraries = nil;
    _linkedFunctions = [[MTLLinkedFunctions alloc] init];
    _supportAddingBinaryFunctions = NO;
    _maxCallStackDepth = 1;
    _shaderValidation = MTLShaderValidationDefault;
    _requiredThreadsPerThreadgroup = MTLSizeMake(0, 0, 0);
}

// The linked functions are null_resettable: a nil set gives the fresh object back, which is the header's
// own word for it.
- (MTLLinkedFunctions *)linkedFunctions
{
    return _linkedFunctions;
}

- (void)setLinkedFunctions:(MTLLinkedFunctions *)linkedFunctions
{
    _linkedFunctions = linkedFunctions ?: [[MTLLinkedFunctions alloc] init];
}

- (MTLShaderValidation)shaderValidation
{
    return _shaderValidation;
}

- (void)setShaderValidation:(MTLShaderValidation)shaderValidation
{
    _shaderValidation = shaderValidation;
}

- (MTLSize)requiredThreadsPerThreadgroup
{
    return _requiredThreadsPerThreadgroup;
}

- (void)setRequiredThreadsPerThreadgroup:(MTLSize)requiredThreadsPerThreadgroup
{
    _requiredThreadsPerThreadgroup = requiredThreadsPerThreadgroup;
}

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    MTLTileRenderPipelineDescriptor *copy = [[MTLTileRenderPipelineDescriptor alloc] init];
    copy.label = _label;
    copy.tileFunction = _tileFunction;
    copy.rasterSampleCount = _rasterSampleCount;
    for (NSUInteger slot = 0; slot < CharonTileColorSlots; slot++)
        copy->_colorAttachments[slot] = _colorAttachments[slot];
    copy.threadgroupSizeMatchesTileSize = _threadgroupSizeMatchesTileSize;
    for (NSUInteger slot = 0; slot < CharonTileBufferSlots; slot++)
        copy->_tileBuffers[slot] = _tileBuffers[slot];
    copy.maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
    copy.binaryArchives = _binaryArchives;
    copy.preloadedLibraries = _preloadedLibraries;
    copy->_linkedFunctions = [[MTLLinkedFunctions alloc] init];
    copy->_linkedFunctions.functions = _linkedFunctions.functions;
    copy->_linkedFunctions.binaryFunctions = _linkedFunctions.binaryFunctions;
    copy->_linkedFunctions.groups = _linkedFunctions.groups;
    copy->_linkedFunctions.privateFunctions = _linkedFunctions.privateFunctions;
    copy.supportAddingBinaryFunctions = _supportAddingBinaryFunctions;
    copy.maxCallStackDepth = _maxCallStackDepth;
    copy.shaderValidation = _shaderValidation;
    copy.requiredThreadsPerThreadgroup = _requiredThreadsPerThreadgroup;
    return copy;
}

@end
