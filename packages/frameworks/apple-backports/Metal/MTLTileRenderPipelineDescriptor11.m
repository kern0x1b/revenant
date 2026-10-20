#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "RevenantMetal26Types.h"

static const NSUInteger RevenantTileColorSlots = 8;
static const NSUInteger RevenantTileBufferSlots = 31;

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

- (void)reset
{
    _label = nil;
    _tileFunction = nil;
    _rasterSampleCount = 1;
    for (NSUInteger slot = 0; slot < RevenantTileColorSlots; slot++)
        _colorAttachments[slot] = nil;
    _threadgroupSizeMatchesTileSize = NO;
    for (NSUInteger slot = 0; slot < RevenantTileBufferSlots; slot++)
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
    for (NSUInteger slot = 0; slot < RevenantTileColorSlots; slot++)
        copy->_colorAttachments[slot] = _colorAttachments[slot];
    copy.threadgroupSizeMatchesTileSize = _threadgroupSizeMatchesTileSize;
    for (NSUInteger slot = 0; slot < RevenantTileBufferSlots; slot++)
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
