#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "RevenantMetal26Types.h"

static const NSUInteger RevenantComputeBufferSlots = 31;

@implementation MTLComputePipelineDescriptor {
    NSString *_label;
    id<MTLFunction> _computeFunction;
    BOOL _threadGroupSizeIsMultipleOfThreadExecutionWidth;
    NSUInteger _maxTotalThreadsPerThreadgroup;
    MTLStageInputOutputDescriptor *_stageInputDescriptor;
    MTLPipelineBufferDescriptorArray *_buffers;
    BOOL _supportIndirectCommandBuffers;
    NSArray *_insertLibraries;
    NSArray *_preloadedLibraries;
    NSArray *_binaryArchives;
    MTLLinkedFunctions *_linkedFunctions;
    BOOL _supportAddingBinaryFunctions;
    NSUInteger _maxCallStackDepth;
    MTLShaderValidation _shaderValidation;
    MTLSize _requiredThreadsPerThreadgroup;
}

@synthesize label = _label;
@synthesize computeFunction = _computeFunction;
@synthesize threadGroupSizeIsMultipleOfThreadExecutionWidth = _threadGroupSizeIsMultipleOfThreadExecutionWidth;
@synthesize maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
@synthesize stageInputDescriptor = _stageInputDescriptor;
@synthesize buffers = _buffers;
@synthesize supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
@synthesize insertLibraries = _insertLibraries;
@synthesize preloadedLibraries = _preloadedLibraries;
@synthesize binaryArchives = _binaryArchives;
@synthesize linkedFunctions = _linkedFunctions;
@synthesize supportAddingBinaryFunctions = _supportAddingBinaryFunctions;
@synthesize maxCallStackDepth = _maxCallStackDepth;

- (instancetype)init
{
    if ((self = [super init])) {
        [self reset];
        _insertLibraries = @[];
        _preloadedLibraries = @[];
    }
    return self;
}

- (void)reset
{
    _label = nil;
    _computeFunction = nil;
    _stageInputDescriptor = [[MTLStageInputOutputDescriptor alloc] init];
    _buffers = [[MTLPipelineBufferDescriptorArray alloc] init];
    _supportIndirectCommandBuffers = NO;
    _insertLibraries = nil;
    _preloadedLibraries = nil;
    _binaryArchives = nil;
    _linkedFunctions = [[MTLLinkedFunctions alloc] init];
    _supportAddingBinaryFunctions = NO;
    _maxCallStackDepth = 1;
    _shaderValidation = MTLShaderValidationDefault;
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
    MTLComputePipelineDescriptor *copy = [[MTLComputePipelineDescriptor alloc] init];
    copy.label = _label;
    copy.computeFunction = _computeFunction;
    copy.threadGroupSizeIsMultipleOfThreadExecutionWidth = _threadGroupSizeIsMultipleOfThreadExecutionWidth;
    copy.maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
    copy->_stageInputDescriptor = [_stageInputDescriptor copy];
    copy->_buffers = [[MTLPipelineBufferDescriptorArray alloc] init];
    for (NSUInteger slot = 0; slot < RevenantComputeBufferSlots; slot++)
        copy->_buffers[slot] = _buffers[slot];
    copy.supportIndirectCommandBuffers = _supportIndirectCommandBuffers;
    copy.insertLibraries = _insertLibraries;
    copy.preloadedLibraries = _preloadedLibraries;
    copy.binaryArchives = _binaryArchives;
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
