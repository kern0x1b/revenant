#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "CharonMetal26Types.h"

// THE MESH RENDER PIPELINE DESCRIPTOR, the class MTLRenderPipeline.h declares at iOS 16.0.
//
// A plain data holder, like the render and tile descriptors beside it: it says what a mesh pipeline is built from,
// and asks no device anything. Nothing here hands back a pipeline state; the descriptor is carried so that a caller
// building one reads back what it wrote. Its functions are a device's objects, so they are only ever nil here.
//
// THE MEMBERS CARRY THE RELEASE THEY ARRIVED IN, and this file holds them all. The members the SDK this package
// compiles against does not declare (the 17.0 supportIndirectCommandBuffers, binaryArchives and linked functions,
// the 18.0 shaderValidation and the 26.0 required sizes) are implemented here as explicit accessors, as the compute
// descriptor carries its later members.
//
// FRESH DEFAULTS, measured on the host (tests/backports/host/mesh-render-pipeline-descriptor): no label or functions,
// every size and threadgroup limit 0, the threadgroup SIMD flags NO, rasterSampleCount 1, alpha to coverage and to one
// NO, rasterization YES, vertex amplification 1, both attachment formats Invalid, indirect command buffers NO, no
// binary archives (nil), the three linked-function sets fresh objects, shader validation Default, and the required
// sizes 0 x 0 x 0. The three buffer arrays and the colour array are fresh, every slot a default descriptor.
//
// -reset restores every member above, measured. It gives the buffer arrays and the colour array NEW objects (the
// identity is not kept), so a caller holding an old one reads its own old values, not the reset ones.
//
// EQUALITY is by value over every member, measured: a fresh descriptor equals another fresh one, and changing any
// member (a colour slot, a buffer slot, the sizes, the flags, a linked-function set) makes them unequal. The binary
// archives are compared as an empty array against nil (measured equal); the functions are compared by identity, as
// nothing here can make one. COPY is a deep copy of the nested objects.

// Apple's colour array has 8 slots and its buffer arrays 31, measured in MTLRenderPipelineDescriptor8.m and
// MTLReflection11.m.
static const NSUInteger CharonMeshColorSlots = 8;
static const NSUInteger CharonMeshBufferSlots = 31;

// The linked functions are copied on set (the property is `copy`, measured: the value read back is not the object set).
static MTLLinkedFunctions *CharonCopyLinkedFunctions(MTLLinkedFunctions *source)
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

static BOOL CharonSameObject(id a, id b)
{
    return a == b || [a isEqual:b];
}

static BOOL CharonSameLinkedFunctions(MTLLinkedFunctions *a, MTLLinkedFunctions *b)
{
    return CharonSameObject(a.functions, b.functions) && CharonSameObject(a.binaryFunctions, b.binaryFunctions) &&
           CharonSameObject(a.groups, b.groups) && CharonSameObject(a.privateFunctions, b.privateFunctions);
}

static BOOL CharonSameColorSlot(MTLRenderPipelineColorAttachmentDescriptor *a, MTLRenderPipelineColorAttachmentDescriptor *b)
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

// A fresh descriptor: the defaults the reset gives, which is all a reset does.
- (instancetype)init
{
    if ((self = [super init]))
        [self reset];
    return self;
}

// Apple's -reset, measured: every member goes back to its default, and the buffer and colour arrays become new objects.
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

// The members the SDK this package compiles against does not declare, as explicit accessors.
- (BOOL)supportIndirectCommandBuffers { return _supportIndirectCommandBuffers; }
- (void)setSupportIndirectCommandBuffers:(BOOL)support { _supportIndirectCommandBuffers = support; }

// The archives are copied on set, as the property is `copy`. nil is an answer of its own: a fresh descriptor has none.
- (NSArray *)binaryArchives { return _binaryArchives; }
- (void)setBinaryArchives:(NSArray *)archives { _binaryArchives = [archives copy]; }

// The linked-function sets are null_resettable and `copy`: a nil set gives a fresh set back, and a set is kept as a copy.
- (MTLLinkedFunctions *)objectLinkedFunctions { return _objectLinkedFunctions; }
- (void)setObjectLinkedFunctions:(MTLLinkedFunctions *)functions
{
    _objectLinkedFunctions = functions ? CharonCopyLinkedFunctions(functions) : [[MTLLinkedFunctions alloc] init];
}

- (MTLLinkedFunctions *)meshLinkedFunctions { return _meshLinkedFunctions; }
- (void)setMeshLinkedFunctions:(MTLLinkedFunctions *)functions
{
    _meshLinkedFunctions = functions ? CharonCopyLinkedFunctions(functions) : [[MTLLinkedFunctions alloc] init];
}

- (MTLLinkedFunctions *)fragmentLinkedFunctions { return _fragmentLinkedFunctions; }
- (void)setFragmentLinkedFunctions:(MTLLinkedFunctions *)functions
{
    _fragmentLinkedFunctions = functions ? CharonCopyLinkedFunctions(functions) : [[MTLLinkedFunctions alloc] init];
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
    for (NSUInteger slot = 0; slot < CharonMeshBufferSlots; slot++) {
        copy->_objectBuffers[slot] = _objectBuffers[slot];
        copy->_meshBuffers[slot] = _meshBuffers[slot];
        copy->_fragmentBuffers[slot] = _fragmentBuffers[slot];
    }
    copy.rasterSampleCount = _rasterSampleCount;
    copy.alphaToCoverageEnabled = _alphaToCoverageEnabled;
    copy.alphaToOneEnabled = _alphaToOneEnabled;
    copy.rasterizationEnabled = _rasterizationEnabled;
    copy.maxVertexAmplificationCount = _maxVertexAmplificationCount;
    for (NSUInteger slot = 0; slot < CharonMeshColorSlots; slot++)
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
    if (!(CharonSameObject(_label, other->_label) && CharonSameObject(_objectFunction, other->_objectFunction) &&
          CharonSameObject(_meshFunction, other->_meshFunction) && CharonSameObject(_fragmentFunction, other->_fragmentFunction)))
        return NO;
    if (!(_maxTotalThreadsPerObjectThreadgroup == other->_maxTotalThreadsPerObjectThreadgroup &&
          _maxTotalThreadsPerMeshThreadgroup == other->_maxTotalThreadsPerMeshThreadgroup &&
          _objectThreadgroupSizeIsMultipleOfThreadExecutionWidth == other->_objectThreadgroupSizeIsMultipleOfThreadExecutionWidth &&
          _meshThreadgroupSizeIsMultipleOfThreadExecutionWidth == other->_meshThreadgroupSizeIsMultipleOfThreadExecutionWidth &&
          _payloadMemoryLength == other->_payloadMemoryLength &&
          _maxTotalThreadgroupsPerMeshGrid == other->_maxTotalThreadgroupsPerMeshGrid))
        return NO;
    for (NSUInteger slot = 0; slot < CharonMeshBufferSlots; slot++) {
        if (_objectBuffers[slot].mutability != other->_objectBuffers[slot].mutability ||
            _meshBuffers[slot].mutability != other->_meshBuffers[slot].mutability ||
            _fragmentBuffers[slot].mutability != other->_fragmentBuffers[slot].mutability)
            return NO;
    }
    if (!(_rasterSampleCount == other->_rasterSampleCount && _alphaToCoverageEnabled == other->_alphaToCoverageEnabled &&
          _alphaToOneEnabled == other->_alphaToOneEnabled && _rasterizationEnabled == other->_rasterizationEnabled &&
          _maxVertexAmplificationCount == other->_maxVertexAmplificationCount))
        return NO;
    for (NSUInteger slot = 0; slot < CharonMeshColorSlots; slot++) {
        if (!CharonSameColorSlot(_colorAttachments[slot], other->_colorAttachments[slot]))
            return NO;
    }
    if (!(_depthAttachmentPixelFormat == other->_depthAttachmentPixelFormat &&
          _stencilAttachmentPixelFormat == other->_stencilAttachmentPixelFormat &&
          _supportIndirectCommandBuffers == other->_supportIndirectCommandBuffers))
        return NO;
    if (![(_binaryArchives ?: @[]) isEqualToArray:(other->_binaryArchives ?: @[])])
        return NO;
    if (!(CharonSameLinkedFunctions(_objectLinkedFunctions, other->_objectLinkedFunctions) &&
          CharonSameLinkedFunctions(_meshLinkedFunctions, other->_meshLinkedFunctions) &&
          CharonSameLinkedFunctions(_fragmentLinkedFunctions, other->_fragmentLinkedFunctions)))
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
