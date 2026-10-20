#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "RevenantMetal26Types.h"

static const NSUInteger RevenantMeshColorSlots = 8;
static const NSUInteger RevenantMeshBufferSlots = 31;

static MTLLinkedFunctions *RevenantCopyLinkedFunctions(MTLLinkedFunctions *source)
{
    MTLLinkedFunctions *copy = [[MTLLinkedFunctions alloc] init];
    if (source) {
        copy.functions = source.functions;
        copy.binaryFunctions = source.binaryFunctions;
        copy.groups = source.groups;
        copy.privateFunctions = source.privateFunctions;
    }
    return copy;
}

static BOOL RevenantSameObject(id a, id b)
{
    return a == b || [a isEqual:b];
}

static BOOL RevenantSameLinkedFunctions(MTLLinkedFunctions *a, MTLLinkedFunctions *b)
{
    return RevenantSameObject(a.functions, b.functions) && RevenantSameObject(a.binaryFunctions, b.binaryFunctions) &&
           RevenantSameObject(a.groups, b.groups) && RevenantSameObject(a.privateFunctions, b.privateFunctions);
}

static BOOL RevenantSameColorSlot(MTLRenderPipelineColorAttachmentDescriptor *a, MTLRenderPipelineColorAttachmentDescriptor *b)
{
    return a.pixelFormat == b.pixelFormat && a.blendingEnabled == b.blendingEnabled &&
           a.sourceRGBBlendFactor == b.sourceRGBBlendFactor && a.destinationRGBBlendFactor == b.destinationRGBBlendFactor &&
           a.rgbBlendOperation == b.rgbBlendOperation && a.sourceAlphaBlendFactor == b.sourceAlphaBlendFactor &&
           a.destinationAlphaBlendFactor == b.destinationAlphaBlendFactor && a.alphaBlendOperation == b.alphaBlendOperation &&
           a.writeMask == b.writeMask;
}

@implementation MTLMeshRenderPipelineDescriptor {
    NSString *_label;
    id<MTLFunction> _objectFunction;
    id<MTLFunction> _meshFunction;
    id<MTLFunction> _fragmentFunction;
    NSUInteger _maxTotalThreadsPerObjectThreadgroup;
    NSUInteger _maxTotalThreadsPerMeshThreadgroup;
    BOOL _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    BOOL _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    NSUInteger _payloadMemoryLength;
    NSUInteger _maxTotalThreadgroupsPerMeshGrid;
    MTLPipelineBufferDescriptorArray *_objectBuffers;
    MTLPipelineBufferDescriptorArray *_meshBuffers;
    MTLPipelineBufferDescriptorArray *_fragmentBuffers;
    NSUInteger _rasterSampleCount;
    BOOL _alphaToCoverageEnabled;
    BOOL _alphaToOneEnabled;
    BOOL _rasterizationEnabled;
    NSUInteger _maxVertexAmplificationCount;
    MTLRenderPipelineColorAttachmentDescriptorArray *_colorAttachments;
    MTLPixelFormat _depthAttachmentPixelFormat;
    MTLPixelFormat _stencilAttachmentPixelFormat;
    BOOL _supportIndirectCommandBuffers;
    NSArray *_binaryArchives;
    MTLLinkedFunctions *_objectLinkedFunctions;
    MTLLinkedFunctions *_meshLinkedFunctions;
    MTLLinkedFunctions *_fragmentLinkedFunctions;
    MTLShaderValidation _shaderValidation;
    MTLSize _requiredThreadsPerObjectThreadgroup;
    MTLSize _requiredThreadsPerMeshThreadgroup;
}

@synthesize label = _label;
@synthesize objectFunction = _objectFunction;
@synthesize meshFunction = _meshFunction;
@synthesize fragmentFunction = _fragmentFunction;
@synthesize maxTotalThreadsPerObjectThreadgroup = _maxTotalThreadsPerObjectThreadgroup;
@synthesize maxTotalThreadsPerMeshThreadgroup = _maxTotalThreadsPerMeshThreadgroup;
@synthesize objectThreadgroupSizeIsMultipleOfThreadExecutionWidth = _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
@synthesize meshThreadgroupSizeIsMultipleOfThreadExecutionWidth = _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
@synthesize payloadMemoryLength = _payloadMemoryLength;
@synthesize maxTotalThreadgroupsPerMeshGrid = _maxTotalThreadgroupsPerMeshGrid;
@synthesize objectBuffers = _objectBuffers;
@synthesize meshBuffers = _meshBuffers;
@synthesize fragmentBuffers = _fragmentBuffers;
@synthesize rasterSampleCount = _rasterSampleCount;
@synthesize alphaToCoverageEnabled = _alphaToCoverageEnabled;
@synthesize alphaToOneEnabled = _alphaToOneEnabled;
@synthesize rasterizationEnabled = _rasterizationEnabled;
@synthesize maxVertexAmplificationCount = _maxVertexAmplificationCount;
@synthesize colorAttachments = _colorAttachments;
@synthesize depthAttachmentPixelFormat = _depthAttachmentPixelFormat;
@synthesize stencilAttachmentPixelFormat = _stencilAttachmentPixelFormat;

- (instancetype)init
{
    if ((self = [super init]))
        [self reset];
    return self;
}

- (void)reset
{
    _label = nil;
    _objectFunction = nil;
    _meshFunction = nil;
    _fragmentFunction = nil;
    _maxTotalThreadsPerObjectThreadgroup = 0;
    _maxTotalThreadsPerMeshThreadgroup = 0;
    _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth = NO;
    _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth = NO;
    _payloadMemoryLength = 0;
    _maxTotalThreadgroupsPerMeshGrid = 0;
    _objectBuffers = [[MTLPipelineBufferDescriptorArray alloc] init];
    _meshBuffers = [[MTLPipelineBufferDescriptorArray alloc] init];
    _fragmentBuffers = [[MTLPipelineBufferDescriptorArray alloc] init];
    _rasterSampleCount = 1;
    _alphaToCoverageEnabled = NO;
    _alphaToOneEnabled = NO;
    _rasterizationEnabled = YES;
    _maxVertexAmplificationCount = 1;
    _colorAttachments = [[MTLRenderPipelineColorAttachmentDescriptorArray alloc] init];
    _depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    _stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
    _supportIndirectCommandBuffers = NO;
    _binaryArchives = nil;
    _objectLinkedFunctions = [[MTLLinkedFunctions alloc] init];
    _meshLinkedFunctions = [[MTLLinkedFunctions alloc] init];
    _fragmentLinkedFunctions = [[MTLLinkedFunctions alloc] init];
    _shaderValidation = MTLShaderValidationDefault;
    _requiredThreadsPerObjectThreadgroup = MTLSizeMake(0, 0, 0);
    _requiredThreadsPerMeshThreadgroup = MTLSizeMake(0, 0, 0);
}

- (BOOL)supportIndirectCommandBuffers { return _supportIndirectCommandBuffers; }
- (void)setSupportIndirectCommandBuffers:(BOOL)support { _supportIndirectCommandBuffers = support; }

- (NSArray *)binaryArchives { return _binaryArchives; }
- (void)setBinaryArchives:(NSArray *)archives { _binaryArchives = [archives copy]; }

- (MTLLinkedFunctions *)objectLinkedFunctions { return _objectLinkedFunctions; }
- (void)setObjectLinkedFunctions:(MTLLinkedFunctions *)functions
{
    _objectLinkedFunctions = functions ? RevenantCopyLinkedFunctions(functions) : [[MTLLinkedFunctions alloc] init];
}

- (MTLLinkedFunctions *)meshLinkedFunctions { return _meshLinkedFunctions; }
- (void)setMeshLinkedFunctions:(MTLLinkedFunctions *)functions
{
    _meshLinkedFunctions = functions ? RevenantCopyLinkedFunctions(functions) : [[MTLLinkedFunctions alloc] init];
}

- (MTLLinkedFunctions *)fragmentLinkedFunctions { return _fragmentLinkedFunctions; }
- (void)setFragmentLinkedFunctions:(MTLLinkedFunctions *)functions
{
    _fragmentLinkedFunctions = functions ? RevenantCopyLinkedFunctions(functions) : [[MTLLinkedFunctions alloc] init];
}

- (MTLShaderValidation)shaderValidation { return _shaderValidation; }
- (void)setShaderValidation:(MTLShaderValidation)shaderValidation { _shaderValidation = shaderValidation; }

- (MTLSize)requiredThreadsPerObjectThreadgroup { return _requiredThreadsPerObjectThreadgroup; }
- (void)setRequiredThreadsPerObjectThreadgroup:(MTLSize)size { _requiredThreadsPerObjectThreadgroup = size; }

- (MTLSize)requiredThreadsPerMeshThreadgroup { return _requiredThreadsPerMeshThreadgroup; }
- (void)setRequiredThreadsPerMeshThreadgroup:(MTLSize)size { _requiredThreadsPerMeshThreadgroup = size; }

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    MTLMeshRenderPipelineDescriptor *copy = [[MTLMeshRenderPipelineDescriptor alloc] init];
    copy.label = _label;
    copy.objectFunction = _objectFunction;
    copy.meshFunction = _meshFunction;
    copy.fragmentFunction = _fragmentFunction;
    copy.maxTotalThreadsPerObjectThreadgroup = _maxTotalThreadsPerObjectThreadgroup;
    copy.maxTotalThreadsPerMeshThreadgroup = _maxTotalThreadsPerMeshThreadgroup;
    copy.objectThreadgroupSizeIsMultipleOfThreadExecutionWidth = _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    copy.meshThreadgroupSizeIsMultipleOfThreadExecutionWidth = _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth;
    copy.payloadMemoryLength = _payloadMemoryLength;
    copy.maxTotalThreadgroupsPerMeshGrid = _maxTotalThreadgroupsPerMeshGrid;
    for (NSUInteger slot = 0; slot < RevenantMeshBufferSlots; slot++) {
        copy->_objectBuffers[slot] = _objectBuffers[slot];
        copy->_meshBuffers[slot] = _meshBuffers[slot];
        copy->_fragmentBuffers[slot] = _fragmentBuffers[slot];
    }
    copy.rasterSampleCount = _rasterSampleCount;
    copy.alphaToCoverageEnabled = _alphaToCoverageEnabled;
    copy.alphaToOneEnabled = _alphaToOneEnabled;
    copy.rasterizationEnabled = _rasterizationEnabled;
    copy.maxVertexAmplificationCount = _maxVertexAmplificationCount;
    for (NSUInteger slot = 0; slot < RevenantMeshColorSlots; slot++)
        copy->_colorAttachments[slot] = _colorAttachments[slot];
    copy.depthAttachmentPixelFormat = _depthAttachmentPixelFormat;
    copy.stencilAttachmentPixelFormat = _stencilAttachmentPixelFormat;
    copy.supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
    copy.binaryArchives = _binaryArchives;
    copy.objectLinkedFunctions = _objectLinkedFunctions;
    copy.meshLinkedFunctions = _meshLinkedFunctions;
    copy.fragmentLinkedFunctions = _fragmentLinkedFunctions;
    copy.shaderValidation = _shaderValidation;
    copy.requiredThreadsPerObjectThreadgroup = _requiredThreadsPerObjectThreadgroup;
    copy.requiredThreadsPerMeshThreadgroup = _requiredThreadsPerMeshThreadgroup;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[MTLMeshRenderPipelineDescriptor class]])
        return NO;
    MTLMeshRenderPipelineDescriptor *other = object;
    if (!(RevenantSameObject(_label, other->_label) && RevenantSameObject(_objectFunction, other->_objectFunction) &&
          RevenantSameObject(_meshFunction, other->_meshFunction) && RevenantSameObject(_fragmentFunction, other->_fragmentFunction)))
        return NO;
    if (!(_maxTotalThreadsPerObjectThreadgroup == other->_maxTotalThreadsPerObjectThreadgroup &&
          _maxTotalThreadsPerMeshThreadgroup == other->_maxTotalThreadsPerMeshThreadgroup &&
          _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth == other->_objectThreadgroupSizeIsMultipleOfThreadExecutionWidth &&
          _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth == other->_meshThreadgroupSizeIsMultipleOfThreadExecutionWidth &&
          _payloadMemoryLength == other->_payloadMemoryLength &&
          _maxTotalThreadgroupsPerMeshGrid == other->_maxTotalThreadgroupsPerMeshGrid))
        return NO;
    for (NSUInteger slot = 0; slot < RevenantMeshBufferSlots; slot++) {
        if (_objectBuffers[slot].mutability != other->_objectBuffers[slot].mutability ||
            _meshBuffers[slot].mutability != other->_meshBuffers[slot].mutability ||
            _fragmentBuffers[slot].mutability != other->_fragmentBuffers[slot].mutability)
            return NO;
    }
    if (!(_rasterSampleCount == other->_rasterSampleCount && _alphaToCoverageEnabled == other->_alphaToCoverageEnabled &&
          _alphaToOneEnabled == other->_alphaToOneEnabled && _rasterizationEnabled == other->_rasterizationEnabled &&
          _maxVertexAmplificationCount == other->_maxVertexAmplificationCount))
        return NO;
    for (NSUInteger slot = 0; slot < RevenantMeshColorSlots; slot++) {
        if (!RevenantSameColorSlot(_colorAttachments[slot], other->_colorAttachments[slot]))
            return NO;
    }
    if (!(_depthAttachmentPixelFormat == other->_depthAttachmentPixelFormat &&
          _stencilAttachmentPixelFormat == other->_stencilAttachmentPixelFormat &&
          _supportIndirectCommandBuffers == other->_supportIndirectCommandBuffers))
        return NO;
    if (![(_binaryArchives ?: @[]) isEqualToArray:(other->_binaryArchives ?: @[])])
        return NO;
    if (!(RevenantSameLinkedFunctions(_objectLinkedFunctions, other->_objectLinkedFunctions) &&
          RevenantSameLinkedFunctions(_meshLinkedFunctions, other->_meshLinkedFunctions) &&
          RevenantSameLinkedFunctions(_fragmentLinkedFunctions, other->_fragmentLinkedFunctions)))
        return NO;
    return _shaderValidation == other->_shaderValidation &&
           _requiredThreadsPerObjectThreadgroup.width == other->_requiredThreadsPerObjectThreadgroup.width &&
           _requiredThreadsPerObjectThreadgroup.height == other->_requiredThreadsPerObjectThreadgroup.height &&
           _requiredThreadsPerObjectThreadgroup.depth == other->_requiredThreadsPerObjectThreadgroup.depth &&
           _requiredThreadsPerMeshThreadgroup.width == other->_requiredThreadsPerMeshThreadgroup.width &&
           _requiredThreadsPerMeshThreadgroup.height == other->_requiredThreadsPerMeshThreadgroup.height &&
           _requiredThreadsPerMeshThreadgroup.depth == other->_requiredThreadsPerMeshThreadgroup.depth;
}

- (NSUInteger)hash
{
    return _maxTotalThreadsPerObjectThreadgroup ^ _maxTotalThreadsPerMeshThreadgroup ^ _payloadMemoryLength ^
           _maxTotalThreadgroupsPerMeshGrid ^ _rasterSampleCount ^ _maxVertexAmplificationCount ^
           (NSUInteger)_depthAttachmentPixelFormat ^ (NSUInteger)_shaderValidation;
}

@end
