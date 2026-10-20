#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@implementation MTLIndirectCommandBufferDescriptor {
    MTLIndirectCommandType _commandTypes;
    BOOL _inheritPipelineState;
    BOOL _inheritBuffers;
    BOOL _inheritDepthStencilState;
    BOOL _inheritDepthBias;
    BOOL _inheritDepthClipMode;
    BOOL _inheritCullMode;
    BOOL _inheritFrontFacingWinding;
    BOOL _inheritTriangleFillMode;
    NSUInteger _maxVertexBufferBindCount;
    NSUInteger _maxFragmentBufferBindCount;
    NSUInteger _maxKernelBufferBindCount;
    NSUInteger _maxKernelThreadgroupMemoryBindCount;
    NSUInteger _maxObjectBufferBindCount;
    NSUInteger _maxMeshBufferBindCount;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _inheritDepthStencilState = YES;
        _inheritDepthBias = YES;
        _inheritDepthClipMode = YES;
        _inheritCullMode = YES;
        _inheritFrontFacingWinding = YES;
        _inheritTriangleFillMode = YES;
        _maxKernelThreadgroupMemoryBindCount = 31;
    }
    return self;
}

@synthesize commandTypes = _commandTypes;
@synthesize inheritPipelineState = _inheritPipelineState;
@synthesize inheritBuffers = _inheritBuffers;
@synthesize maxVertexBufferBindCount = _maxVertexBufferBindCount;
@synthesize maxFragmentBufferBindCount = _maxFragmentBufferBindCount;
@synthesize maxKernelBufferBindCount = _maxKernelBufferBindCount;

- (BOOL)inheritDepthStencilState { return _inheritDepthStencilState; }
- (void)setInheritDepthStencilState:(BOOL)inherit { _inheritDepthStencilState = inherit; }
- (BOOL)inheritDepthBias { return _inheritDepthBias; }
- (void)setInheritDepthBias:(BOOL)inherit { _inheritDepthBias = inherit; }
- (BOOL)inheritDepthClipMode { return _inheritDepthClipMode; }
- (void)setInheritDepthClipMode:(BOOL)inherit { _inheritDepthClipMode = inherit; }
- (BOOL)inheritCullMode { return _inheritCullMode; }
- (void)setInheritCullMode:(BOOL)inherit { _inheritCullMode = inherit; }
- (BOOL)inheritFrontFacingWinding { return _inheritFrontFacingWinding; }
- (void)setInheritFrontFacingWinding:(BOOL)inherit { _inheritFrontFacingWinding = inherit; }
- (BOOL)inheritTriangleFillMode { return _inheritTriangleFillMode; }
- (void)setInheritTriangleFillMode:(BOOL)inherit { _inheritTriangleFillMode = inherit; }
- (NSUInteger)maxKernelThreadgroupMemoryBindCount { return _maxKernelThreadgroupMemoryBindCount; }
- (void)setMaxKernelThreadgroupMemoryBindCount:(NSUInteger)count { _maxKernelThreadgroupMemoryBindCount = count; }
- (NSUInteger)maxObjectBufferBindCount { return _maxObjectBufferBindCount; }
- (void)setMaxObjectBufferBindCount:(NSUInteger)count { _maxObjectBufferBindCount = count; }
- (NSUInteger)maxMeshBufferBindCount { return _maxMeshBufferBindCount; }
- (void)setMaxMeshBufferBindCount:(NSUInteger)count { _maxMeshBufferBindCount = count; }

- (id)copyWithZone:(NSZone *)zone
{
    (void)zone;
    MTLIndirectCommandBufferDescriptor *copy = [[MTLIndirectCommandBufferDescriptor alloc] init];
    copy.commandTypes = _commandTypes;
    copy.inheritPipelineState = _inheritPipelineState;
    copy.inheritBuffers = _inheritBuffers;
    copy->_inheritDepthStencilState = _inheritDepthStencilState;
    copy->_inheritDepthBias = _inheritDepthBias;
    copy->_inheritDepthClipMode = _inheritDepthClipMode;
    copy->_inheritCullMode = _inheritCullMode;
    copy->_inheritFrontFacingWinding = _inheritFrontFacingWinding;
    copy->_inheritTriangleFillMode = _inheritTriangleFillMode;
    copy.maxVertexBufferBindCount = _maxVertexBufferBindCount;
    copy.maxFragmentBufferBindCount = _maxFragmentBufferBindCount;
    copy.maxKernelBufferBindCount = _maxKernelBufferBindCount;
    copy->_maxKernelThreadgroupMemoryBindCount = _maxKernelThreadgroupMemoryBindCount;
    copy->_maxObjectBufferBindCount = _maxObjectBufferBindCount;
    copy->_maxMeshBufferBindCount = _maxMeshBufferBindCount;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[MTLIndirectCommandBufferDescriptor class]])
        return NO;
    MTLIndirectCommandBufferDescriptor *other = object;
    return _commandTypes == other->_commandTypes &&
           _inheritPipelineState == other->_inheritPipelineState && _inheritBuffers == other->_inheritBuffers &&
           _inheritDepthStencilState == other->_inheritDepthStencilState && _inheritDepthBias == other->_inheritDepthBias &&
           _inheritDepthClipMode == other->_inheritDepthClipMode && _inheritCullMode == other->_inheritCullMode &&
           _inheritFrontFacingWinding == other->_inheritFrontFacingWinding &&
           _inheritTriangleFillMode == other->_inheritTriangleFillMode &&
           _maxVertexBufferBindCount == other->_maxVertexBufferBindCount &&
           _maxFragmentBufferBindCount == other->_maxFragmentBufferBindCount &&
           _maxKernelBufferBindCount == other->_maxKernelBufferBindCount &&
           _maxKernelThreadgroupMemoryBindCount == other->_maxKernelThreadgroupMemoryBindCount &&
           _maxObjectBufferBindCount == other->_maxObjectBufferBindCount &&
           _maxMeshBufferBindCount == other->_maxMeshBufferBindCount;
}

- (NSUInteger)hash
{
    return (NSUInteger)_commandTypes ^ _maxVertexBufferBindCount ^ _maxFragmentBufferBindCount ^ _maxKernelBufferBindCount ^
           _maxKernelThreadgroupMemoryBindCount ^ _maxObjectBufferBindCount ^ _maxMeshBufferBindCount;
}

@end
