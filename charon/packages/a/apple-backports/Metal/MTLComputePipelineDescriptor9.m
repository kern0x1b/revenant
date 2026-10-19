#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "CharonMetal26Types.h"

// THE COMPUTE PIPELINE DESCRIPTOR, the class MTLComputePipeline.h declares at iOS 9.0.
//
// It is a plain data holder, the same as the 14.0 descriptors in MTLDescriptors14.m: it says what a
// compute pipeline is built from, and none of it asks a device anything. A device is what would turn it
// into an MTLComputePipelineState, and this port has no descriptor path for that yet, so nothing here
// hands a state back; the descriptor is carried so that a caller building one reads back what it wrote.
//
// THE MEMBERS CARRY THE RELEASE THEY ARRIVED IN, and the class file holds all of them, as
// MTLDescriptors14.m holds the 16.x members of its own classes: the release-split check reads the class
// symbol, which is 9.0, and a member's availability is the header's. The members introduced after the SDK
// the package compiles against (shaderValidation at 18.0, requiredThreadsPerThreadgroup at 26.0) are
// declared by CharonMetal26Types.h for that SDK and implemented here as explicit accessors.
//
// FRESH DEFAULTS, measured on the host (tests/backports/host/compute-pipeline-descriptor):
//   * stageInputDescriptor is a fresh MTLStageInputOutputDescriptor, not nil;
//   * buffers is a fresh MTLPipelineBufferDescriptorArray, and every slot answers a descriptor;
//   * insertLibraries and preloadedLibraries are empty arrays, not nil;
//   * linkedFunctions is a fresh MTLLinkedFunctions, not nil;
//   * maxCallStackDepth is 1, and shaderValidation is MTLShaderValidationDefault.
//
// -reset is NOT a fresh descriptor. Measured on the host, it restores the members listed in its body and
// leaves three of them as they were set: threadGroupSizeIsMultipleOfThreadExecutionWidth, maxTotalThreads-
// PerThreadgroup and requiredThreadsPerThreadgroup. It also sets the two library arrays to nil, where a
// fresh descriptor has them empty.
//
// COPY is a deep copy of the nested objects: the copy's stage input, buffers and linked functions are new
// objects, and a buffer slot set in the original reads back in the copy with the mutability it had.

// The buffer slots Apple's array has, measured in MTLReflection11.m (CharonMetalPipelineBufferSlots there): 31.
static const NSUInteger CharonComputeBufferSlots = 31;

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

// A fresh descriptor: the reset's values, with the two library arrays empty rather than nil. The flags, the
// size and the threadgroup limit start at zero, which is what their ivars are.
- (instancetype)init
{
    if ((self = [super init])) {
        [self reset];
        _insertLibraries = @[];
        _preloadedLibraries = @[];
    }
    return self;
}

// Apple's -reset, measured: restores the label, the computeFunction, the nested objects, the flags for indirect
// command buffers and binary functions, the call-stack depth and shader validation, and sets the two library
// arrays and the binary archives to nil. It does NOT restore threadGroupSizeIsMultipleOfThreadExecutionWidth,
// maxTotalThreadsPerThreadgroup or requiredThreadsPerThreadgroup, which keep the values they were set to.
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

// The accessors the SDK this package compiles against does not declare. Their types come from
// CharonMetal26Types.h, and a host built against the SDK that declares them takes these definitions for
// the header's own.
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
    for (NSUInteger slot = 0; slot < CharonComputeBufferSlots; slot++)
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
